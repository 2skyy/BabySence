"""BabySense AI 분석 서버.

역할은 **추론뿐**입니다. 기록 저장은 Supabase가 앱과 직접 처리하고,
분석 결과를 skin_analyses에 남기는 것도 앱이 합니다. 그래서 이 서버는 DB에
붙지 않습니다.

두 엔드포인트 모두 요청마다 Claude 크레딧을 쓰므로, 앱이 보낸 Supabase 액세스
토큰이 유효한지만 확인합니다(app/auth.py). 인가(누가 어떤 행을 볼 수 있는가)는
여전히 Supabase의 RLS가 앱과 직접 처리합니다.

**둘은 같은 API 키를 씁니다.** 곧 같은 크레딧을 나눠 쓰므로, 한쪽이 폭주하면
다른 쪽이 멈춥니다. 그래서 횟수 상한을 기능별로 따로 셉니다.

실행:
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""

import logging
from contextlib import asynccontextmanager
from typing import Annotated, Literal

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import advice, auth, skin
from .config import settings
from .ratelimit import SlidingWindow

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 모델은 시작할 때 한 번만 읽습니다. 요청마다 읽으면 느립니다.
    # 모델이 없어도 서버는 뜨고, 해당 엔드포인트만 503을 반환합니다.
    skin.model.load()
    advice.client.load()
    yield
    await auth.close()


app = FastAPI(title="BabySense AI Server", version="0.1.0", lifespan=lifespan)

# 모바일 앱은 Origin을 보내지 않으므로 CORS와 무관하게 동작합니다.
# 그래서 기본값은 "아무 출처도 허용하지 않음"입니다. 브라우저에서 부를 일이
# 생기면 CORS_ORIGINS에 그 주소만 적으세요.
#
# 예전에는 allow_origins=["*"] + allow_credentials=True였는데, 이 조합에서
# Starlette은 요청이 보낸 Origin을 그대로 되돌려줍니다 — 사실상 모든 사이트를
# 허용하는 것과 같습니다.
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

#: 사용자 한 명이 부를 수 있는 횟수.
_per_user_limit = SlidingWindow(
    limit=settings.advice_rate_limit,
    window_seconds=settings.advice_rate_window_seconds,
)

#: 서버 전체 상한. 계정은 얼마든지 새로 만들 수 있어 사용자별 상한만으로는
#: 총액이 막히지 않습니다.
_global_limit = SlidingWindow(
    limit=settings.advice_global_rate_limit,
    window_seconds=settings.advice_rate_window_seconds,
)

#: 피부 분석은 **통을 따로 씁니다.** 사진 한 장은 글자 질문보다 토큰을 훨씬
#: 많이 먹습니다. 같은 통에 넣으면 사진 몇 장에 상담이 막히고, 반대로 상담에
#: 맞춰 넉넉히 열면 사진 쪽이 크레딧을 다 태웁니다. 두 기능이 같은 API 키,
#: 곧 **같은 지갑**을 쓰기 때문에 통을 나누는 것이 서로를 지키는 장치입니다.
_skin_per_user_limit = SlidingWindow(
    limit=settings.skin_rate_limit,
    window_seconds=settings.advice_rate_window_seconds,
)
_skin_global_limit = SlidingWindow(
    limit=settings.skin_global_rate_limit,
    window_seconds=settings.advice_rate_window_seconds,
)


async def _read_upload(file: UploadFile) -> bytes:
    """업로드 본문을 읽고 크기 상한을 확인합니다."""
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="빈 파일입니다.")
    if len(data) > settings.max_upload_bytes:
        limit_mb = settings.max_upload_bytes // (1024 * 1024)
        raise HTTPException(
            status_code=413,
            detail=f"파일이 너무 큽니다. {limit_mb}MB 이하만 업로드할 수 있습니다.",
        )
    return data


@app.get("/health")
async def health() -> dict:
    """모델별 준비 상태까지 보여줍니다. 어느 기능이 살아 있는지 바로 알 수 있습니다."""
    return {
        "status": "ok",
        "models": {
            "skin": {"ready": skin.model.is_ready},
            "advice": {"ready": advice.client.ready},
        },
    }


class ChatMessage(BaseModel):
    """대화의 한 마디.

    길이 상한이 역할마다 다릅니다. 질문은 사용자가 적는 값이라 좁게 막지만,
    답변은 우리가 만든 값이라 같은 잣대를 댈 이유가 없습니다. 예전에는 둘 다
    500자로 두어, 답변이 길어지는 순간 그 대화가 통째로 막혔습니다.
    """

    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=settings.max_answer_chars)


class AdviceRequest(BaseModel):
    """대화 한 번의 요청.

    이 서버는 대화를 **저장하지 않습니다.** DB에 붙지 않고, 여러 대에 띄워도
    같은 답을 내야 하기 때문입니다. 기억은 앱이 들고 있고 매번 전부 보냅니다.

    맥락(개월 수, 성별, 최근 기록, 앱이 낸 판정)도 **앱이 조립해 보냅니다.**
    아이 이름처럼 개인을 특정하는 값은 보내지 마세요.
    """

    messages: list[ChatMessage] = Field(min_length=1)
    domain: str = Field(default="overall")
    context: str | None = Field(default=None, max_length=settings.max_context_chars)


@app.post("/api/advice")
async def get_advice(
    request: AdviceRequest,
    user_id: Annotated[str, Depends(auth.require_user)],
) -> dict:
    """보호자의 질문에 Claude가 답합니다.

    진단하지 않습니다. 앱의 규칙 기반 판정을 대신하지도 않습니다.
    판정이 맥락으로 들어오면 그 판정을 풀어 설명하는 역할입니다.

    **로그인한 사용자만 부를 수 있습니다.** 요청 한 번마다 Claude 크레딧을
    쓰기 때문입니다. 앱은 Supabase 액세스 토큰을 Authorization 헤더에
    실어 보냅니다.
    """
    if request.domain not in advice.DOMAINS:
        raise HTTPException(
            status_code=400,
            detail=f"알 수 없는 영역입니다: {request.domain}",
        )

    if len(request.messages) > settings.max_chat_messages:
        raise HTTPException(
            status_code=413,
            detail="대화가 너무 길어졌습니다. 새 대화를 시작해 주세요.",
        )

    # 마지막은 보호자의 말이어야 합니다. 답변으로 끝나 있으면 물어볼 것이
    # 없는데 모델을 부르는 셈입니다.
    if request.messages[-1].role != "user":
        raise HTTPException(status_code=400, detail="질문이 없습니다.")

    # 질문 길이는 **이번에 물은 것**에만 겁니다. 대화 전체에 걸면 앞선 답변
    # 때문에 새 질문이 막힙니다.
    if len(request.messages[-1].content) > settings.max_question_chars:
        raise HTTPException(
            status_code=400,
            detail=f"질문은 {settings.max_question_chars}자 이하로 적어 주세요.",
        )

    # 상한은 모델을 부르기 **전에** 봅니다. 부른 뒤에 세면 이미 돈이 나갑니다.
    if not _global_limit.allow("*"):
        logger.warning("서버 전체 상한에 걸렸습니다.")
        raise HTTPException(
            status_code=429,
            detail="지금 이용이 많습니다. 잠시 후 다시 시도해 주세요.",
            headers={"Retry-After": str(_global_limit.retry_after_seconds("*"))},
        )

    if not _per_user_limit.allow(user_id):
        raise HTTPException(
            status_code=429,
            detail="질문을 너무 많이 하셨습니다. 잠시 후 다시 시도해 주세요.",
            headers={
                "Retry-After": str(_per_user_limit.retry_after_seconds(user_id))
            },
        )

    try:
        # Anthropic 클라이언트는 동기라 그대로 부르면 이벤트 루프를 막습니다.
        # 답변 하나가 몇 초 걸리는 동안 /health도 다른 사람의 인증 확인도
        # 줄을 서게 됩니다.
        answer = await run_in_threadpool(
            advice.client.ask,
            messages=[m.model_dump() for m in request.messages],
            domain=request.domain,
            context=request.context,
        )
    except Exception as exc:  # noqa: BLE001
        status, detail = advice.to_http_detail(exc)
        raise HTTPException(status_code=status, detail=detail) from exc

    # 고지는 서버가 붙입니다. 모델이 쓰게 두면 답변마다 문구가 달라집니다.
    return {
        "status": "success",
        "answer": answer.text,
        # 토큰 상한에 걸려 문장이 끊긴 경우. 앱이 그 사실을 밝혀 줍니다.
        "truncated": answer.truncated,
        "disclaimer": advice.DISCLAIMER,
    }


@app.post("/api/skin/diagnose")
async def diagnose_skin(
    user_id: Annotated[str, Depends(auth.require_user)],
    file: UploadFile = File(...),
) -> dict:
    """피부 사진을 보고 지금 무엇을 하면 좋을지 안내합니다.

    **진단하지 않습니다.** 병명을 붙이지 않고, 암은 다루지 않습니다.
    보이는 것을 옮기고 단계(정상/주의/상담 권장)를 정할 뿐입니다.

    **로그인한 사용자만 부를 수 있습니다.** 예전에는 열려 있었는데, 그때는
    고정값을 돌려주는 자리라 크레딧이 나가지 않았기 때문입니다. 이제 사진
    한 장마다 Claude를 부르므로 상담과 같은 문을 씁니다.
    """
    image = await _read_upload(file)

    # 형식은 매직 바이트로 봅니다. 확장자와 Content-Type은 보내는 쪽이
    # 마음대로 적을 수 있고, 틀리면 Anthropic이 영문 400을 내는데 그 문구가
    # 그대로 보호자 화면에 뜹니다.
    media_type = skin.detect_media_type(image)
    if media_type is None:
        raise HTTPException(
            status_code=400,
            detail="사진 파일만 올릴 수 있습니다. JPG나 PNG로 다시 시도해 주세요.",
        )

    # 상한은 모델을 부르기 **전에** 봅니다. 부른 뒤에 세면 이미 돈이 나갑니다.
    if not _skin_global_limit.allow("*"):
        logger.warning("피부 분석 서버 전체 상한에 걸렸습니다.")
        raise HTTPException(
            status_code=429,
            detail="지금 이용이 많습니다. 잠시 후 다시 시도해 주세요.",
            headers={"Retry-After": str(_skin_global_limit.retry_after_seconds("*"))},
        )

    if not _skin_per_user_limit.allow(user_id):
        raise HTTPException(
            status_code=429,
            detail="사진을 너무 많이 보내셨습니다. 잠시 후 다시 시도해 주세요.",
            headers={
                "Retry-After": str(_skin_per_user_limit.retry_after_seconds(user_id))
            },
        )

    try:
        # Anthropic 클라이언트는 동기라 그대로 부르면 이벤트 루프를 막습니다.
        reading = await run_in_threadpool(skin.model.read, image, media_type)
    except skin.SkinModelUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        status, detail = advice.to_http_detail(exc)
        raise HTTPException(status_code=status, detail=detail) from exc

    # 피부가 아니거나 판독이 안 되는 사진. 단계를 내보내면 화면이 '정상'으로
    # 그립니다 — 확인이 안 됐다는 사실과 정상은 다른 말입니다.
    if not reading.is_skin:
        return {
            "status": "unreadable",
            "message": reading.advice,
            "disclaimer": advice.DISCLAIMER,
        }

    return {
        "status": "success",
        "level": reading.level,
        "urgent": reading.urgent,
        "observations": reading.observations,
        "advice": reading.advice,
        # 고지는 서버가 붙입니다. 모델이 쓰게 두면 결과마다 문구가 달라집니다.
        "disclaimer": advice.DISCLAIMER,
    }
