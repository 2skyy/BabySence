"""토큰 검증.

/api/advice는 요청마다 Claude 크레딧을 씁니다. 여기가 뚫리면 서버 주소를
아는 누구나 무제한으로 태울 수 있으므로, 막아야 할 경우를 하나씩 확인합니다.

Supabase를 실제로 부르지 않습니다. 대신 응답을 흉내 내는 전송 계층을 끼워
넣어, **우리가 어떤 응답에 어떻게 반응하는지**를 확인합니다.
"""

import asyncio
import sys
from pathlib import Path

import httpx
import pytest
from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import auth  # noqa: E402
from app.config import settings  # noqa: E402


def _use_fake_supabase(monkeypatch, handler):
    """Supabase 응답을 흉내 내는 클라이언트를 끼워 넣습니다."""
    monkeypatch.setattr(settings, "supabase_url", "https://project.supabase.co")
    monkeypatch.setattr(settings, "supabase_publishable_key", "sb_publishable_test")
    monkeypatch.setattr(
        auth, "_client", httpx.AsyncClient(transport=httpx.MockTransport(handler))
    )
    auth._cache.clear()


def _ok(_request):
    return httpx.Response(200, json={"id": "user-1", "email": "a@b.c"})


class TestBearerHeader:
    """헤더 모양만으로 걸러낼 수 있는 것들."""

    def test_missing_header_is_401(self):
        with pytest.raises(HTTPException) as e:
            auth._bearer(None)
        assert e.value.status_code == 401

    def test_wrong_scheme_is_401(self):
        with pytest.raises(HTTPException) as e:
            auth._bearer("Basic abc123")
        assert e.value.status_code == 401

    def test_empty_token_is_401(self):
        with pytest.raises(HTTPException) as e:
            auth._bearer("Bearer   ")
        assert e.value.status_code == 401

    def test_accepts_bearer(self):
        assert auth._bearer("Bearer abc123") == "abc123"

    def test_scheme_is_case_insensitive(self):
        assert auth._bearer("bearer abc123") == "abc123"


class TestVerify:
    def test_returns_user_id(self, monkeypatch):
        _use_fake_supabase(monkeypatch, _ok)
        assert asyncio.run(auth._verify("token")) == "user-1"

    def test_sends_the_token_to_supabase(self, monkeypatch):
        seen = {}

        def handler(request):
            seen["auth"] = request.headers.get("authorization")
            seen["apikey"] = request.headers.get("apikey")
            seen["url"] = str(request.url)
            return _ok(request)

        _use_fake_supabase(monkeypatch, handler)
        asyncio.run(auth._verify("token"))

        assert seen["auth"] == "Bearer token"
        assert seen["apikey"] == "sb_publishable_test"
        assert seen["url"].endswith("/auth/v1/user")

    def test_rejected_token_is_401(self, monkeypatch):
        _use_fake_supabase(
            monkeypatch, lambda r: httpx.Response(401, json={"msg": "bad jwt"})
        )
        with pytest.raises(HTTPException) as e:
            asyncio.run(auth._verify("token"))
        assert e.value.status_code == 401

    def test_response_without_id_is_401(self, monkeypatch):
        # 200이어도 사용자를 특정하지 못하면 통과시키지 않습니다.
        _use_fake_supabase(monkeypatch, lambda r: httpx.Response(200, json={}))
        with pytest.raises(HTTPException) as e:
            asyncio.run(auth._verify("token"))
        assert e.value.status_code == 401

    def test_supabase_outage_does_not_open_the_door(self, monkeypatch):
        # Supabase가 죽었다고 인증 없이 통과시키면, 그때가 가장 위험합니다.
        _use_fake_supabase(monkeypatch, lambda r: httpx.Response(500))
        with pytest.raises(HTTPException) as e:
            asyncio.run(auth._verify("token"))
        assert e.value.status_code == 503

    def test_network_failure_does_not_open_the_door(self, monkeypatch):
        def boom(request):
            raise httpx.ConnectError("연결 실패")

        _use_fake_supabase(monkeypatch, boom)
        with pytest.raises(HTTPException) as e:
            asyncio.run(auth._verify("token"))
        assert e.value.status_code == 503

    def test_missing_config_does_not_open_the_door(self, monkeypatch):
        # 설정을 빠뜨렸을 때 조용히 인증 없는 서버가 되면 안 됩니다.
        _use_fake_supabase(monkeypatch, _ok)
        monkeypatch.setattr(settings, "supabase_url", None)
        with pytest.raises(HTTPException) as e:
            asyncio.run(auth._verify("token"))
        assert e.value.status_code == 503


class TestCache:
    def test_reuses_the_result_for_the_same_token(self, monkeypatch):
        # 대화 한 번에 여러 턴이 오갑니다. 매 턴 Supabase까지 다녀오면
        # 답변마다 왕복이 하나씩 더 붙습니다.
        calls = []

        def handler(request):
            calls.append(1)
            return _ok(request)

        _use_fake_supabase(monkeypatch, handler)
        asyncio.run(auth._verify("token"))
        asyncio.run(auth._verify("token"))
        assert len(calls) == 1

    def test_different_tokens_are_checked_separately(self, monkeypatch):
        calls = []

        def handler(request):
            calls.append(1)
            return _ok(request)

        _use_fake_supabase(monkeypatch, handler)
        asyncio.run(auth._verify("token-a"))
        asyncio.run(auth._verify("token-b"))
        assert len(calls) == 2

    def test_does_not_cache_a_rejection(self, monkeypatch):
        # 거절을 캐시하면 다시 로그인해도 한동안 막힙니다.
        _use_fake_supabase(monkeypatch, lambda r: httpx.Response(401))
        with pytest.raises(HTTPException):
            asyncio.run(auth._verify("token"))
        assert auth._cache == {}

    def test_does_not_keep_raw_tokens(self, monkeypatch):
        # 캐시 키가 그대로 토큰이면 덤프나 로그에 원본이 섞여 나옵니다.
        _use_fake_supabase(monkeypatch, _ok)
        asyncio.run(auth._verify("secret-token"))
        assert "secret-token" not in auth._cache
