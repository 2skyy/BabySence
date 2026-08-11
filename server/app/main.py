"""BabySense AI 분석 서버.

역할은 **추론뿐**입니다. 인증과 기록 저장은 Supabase가 앱과 직접 처리하고,
분석 결과를 skin_analyses에 남기는 것도 앱이 합니다.
그래서 이 서버는 DB에 붙지 않고, 사용자 JWT를 다룰 필요도 없습니다.

주의: 현재 피부 모델이 준비되지 않아 **동작하는 추론 엔드포인트가 없습니다.**
/health는 응답하지만 /api/skin/diagnose는 503을 반환합니다.

실행:
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import advice, skin
from .config import settings

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


app = FastAPI(title="BabySense AI Server", version="0.1.0", lifespan=lifespan)

# 앱(모바일)에서 직접 호출합니다. 개발 편의를 위해 열어두었고,
# 배포 시에는 실제 출처만 남기세요.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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


class AdviceRequest(BaseModel):
    """육아 질문 한 건.

    맥락(개월 수, 최근 기록, 앱이 낸 판정)은 **앱이 조립해 보냅니다.**
    이 서버는 DB에 붙지 않으므로 기록을 직접 조회할 수 없습니다.
    개인을 특정할 수 있는 값(이름, 아이디)은 보내지 마세요.
    """

    question: str = Field(min_length=2, max_length=settings.max_question_chars)
    domain: str = Field(default="overall")
    context: str | None = Field(default=None, max_length=settings.max_context_chars)


@app.post("/api/advice")
async def get_advice(request: AdviceRequest) -> dict:
    """보호자의 질문에 Claude가 답합니다.

    진단하지 않습니다. 앱의 규칙 기반 판정을 대신하지도 않습니다.
    판정이 맥락으로 들어오면 그 판정을 풀어 설명하는 역할입니다.
    """
    if request.domain not in advice.DOMAINS:
        raise HTTPException(
            status_code=400,
            detail=f"알 수 없는 영역입니다: {request.domain}",
        )

    try:
        answer = advice.client.ask(
            question=request.question,
            domain=request.domain,
            context=request.context,
        )
    except Exception as exc:  # noqa: BLE001
        status, detail = advice.to_http_detail(exc)
        raise HTTPException(status_code=status, detail=detail) from exc

    # 고지는 서버가 붙입니다. 모델이 쓰게 두면 답변마다 문구가 달라집니다.
    return {
        "status": "success",
        "answer": answer,
        "disclaimer": advice.DISCLAIMER,
    }


@app.post("/api/skin/diagnose")
async def diagnose_skin(file: UploadFile = File(...)) -> dict:
    """피부 사진 진단.

    확률이 기준(기본 50%)에 못 미치면 진단명을 내놓지 않고 재촬영을 안내합니다.
    조명이 나쁜 사진에 그럴듯한 병명을 붙이는 것을 막기 위한 기준입니다.
    """
    image = await _read_upload(file)

    try:
        disease, probability = skin.model.predict(image)
    except skin.SkinModelUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        logger.exception("피부 분석 실패")
        raise HTTPException(
            status_code=500, detail=f"피부 상태를 분석하지 못했습니다: {exc}"
        ) from exc

    if probability < settings.skin_min_probability:
        return {
            "status": "low_confidence",
            "disease": disease,
            "probability": probability,
            "message": "정확한 판독이 어렵습니다. 깨끗한 조명에서 환부를 다시 촬영해 주세요.",
        }

    return {"status": "success", "disease": disease, "probability": probability}
