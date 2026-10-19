"""Supabase에 로그인한 사용자만 답변을 받을 수 있게 합니다.

이 서버는 요청 한 번마다 Claude 크레딧을 씁니다. 인증이 없으면 주소를 아는
누구나 무제한으로 태울 수 있습니다. 앱은 이미 Supabase로 로그인해 있으므로
그 토큰을 그대로 들려 보내면 됩니다.

**서명을 직접 확인하지 않고 Supabase에 물어봅니다**(`GET /auth/v1/user`).
이 프로젝트의 토큰은 ES256(비대칭)이라 직접 검증하려면 JWKS를 받아 캐시하고
키 회전까지 따라가야 합니다. 코드가 늘고, 키가 바뀌면 조용히 깨집니다.
왕복이 한 번 늘지만 답변 자체가 몇 초 걸리므로 묻히는 시간입니다.

같은 토큰은 잠깐 캐시해 둡니다. 대화 한 번에 여러 턴이 오가는데 매 턴
Supabase까지 다녀올 이유가 없습니다.
"""

import hashlib
import logging
import time
from typing import Annotated

import httpx
from fastapi import Header, HTTPException

from .config import settings

logger = logging.getLogger(__name__)

#: 검증 결과를 들고 있는 시간(초). 토큰 만료보다 훨씬 짧게 둡니다 —
#: 로그아웃한 사용자가 이 시간만큼은 더 쓸 수 있다는 뜻이기 때문입니다.
_CACHE_TTL_SECONDS = 60

#: 캐시가 무한정 커지지 않도록 하는 상한.
_CACHE_MAX_ENTRIES = 1000

#: 토큰 해시 -> (사용자 id, 만료 시각)
_cache: dict[str, tuple[str, float]] = {}

_client: httpx.AsyncClient | None = None


def _http() -> httpx.AsyncClient:
    global _client
    if _client is None:
        # 로그인 확인이 오래 걸리면 답변까지 늦어집니다. 짧게 끊습니다.
        _client = httpx.AsyncClient(timeout=5.0)
    return _client


async def close() -> None:
    """서버가 내려갈 때 연결을 정리합니다."""
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


def _bearer(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="로그인이 필요합니다.")

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=401, detail="로그인이 필요합니다.")

    return token.strip()


async def _verify(token: str) -> str:
    """토큰이 유효하면 사용자 id를 돌려줍니다."""
    if not settings.supabase_url or not settings.supabase_publishable_key:
        # 열어 두는 대신 막습니다. 설정을 빠뜨렸을 때 조용히 인증 없는
        # 서버가 되는 쪽이 훨씬 나쁩니다.
        logger.error("SUPABASE_URL 또는 SUPABASE_PUBLISHABLE_KEY가 없습니다.")
        raise HTTPException(
            status_code=503,
            detail="서버 설정이 끝나지 않았습니다. 잠시 후 다시 시도해 주세요.",
        )

    key = hashlib.sha256(token.encode()).hexdigest()
    now = time.monotonic()

    cached = _cache.get(key)
    if cached is not None and cached[1] > now:
        return cached[0]

    try:
        response = await _http().get(
            f"{settings.supabase_url.rstrip('/')}/auth/v1/user",
            headers={
                "apikey": settings.supabase_publishable_key,
                "Authorization": f"Bearer {token}",
            },
        )
    except httpx.HTTPError as exc:
        logger.warning("Supabase 로그인 확인 실패: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="로그인 확인에 실패했습니다. 잠시 후 다시 시도해 주세요.",
        ) from exc

    if response.status_code == 401 or response.status_code == 403:
        raise HTTPException(
            status_code=401,
            detail="로그인이 만료되었습니다. 다시 로그인해 주세요.",
        )

    if response.status_code >= 400:
        logger.warning("Supabase가 %s를 반환했습니다.", response.status_code)
        raise HTTPException(
            status_code=503,
            detail="로그인 확인에 실패했습니다. 잠시 후 다시 시도해 주세요.",
        )

    user_id = response.json().get("id")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail="로그인이 만료되었습니다. 다시 로그인해 주세요.",
        )

    if len(_cache) >= _CACHE_MAX_ENTRIES:
        # 만료된 것부터 버리고, 그래도 넘치면 통째로 비웁니다. 다시 채우는
        # 비용은 왕복 한 번이라 굳이 정교하게 고를 이유가 없습니다.
        for stale in [k for k, (_, exp) in _cache.items() if exp <= now]:
            del _cache[stale]
        if len(_cache) >= _CACHE_MAX_ENTRIES:
            _cache.clear()

    _cache[key] = (user_id, now + _CACHE_TTL_SECONDS)
    return user_id


async def require_user(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """로그인한 사용자의 id를 돌려주는 의존성. 아니면 401을 던집니다."""
    return await _verify(_bearer(authorization))
