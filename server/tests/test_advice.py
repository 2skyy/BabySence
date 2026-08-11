"""API 키 없이 확인할 수 있는 부분만 다룹니다.

실제 Claude 호출(답변 품질, 거절 처리)은 키가 있어야 확인할 수 있습니다.
여기서는 프롬프트 조립, 입력 검증, 오류 매핑을 고정합니다.

실행:
    cd server && source venv/bin/activate && python -m pytest tests -q
"""

import anthropic
import pytest
from fastapi.testclient import TestClient

from app import advice
from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


class TestPrompt:
    def test_영역을_한국어_이름으로_바꾼다(self):
        prompt = advice._build_prompt("열이 나요", "temperature", None)
        assert "체온·발열" in prompt
        assert "열이 나요" in prompt

    def test_맥락이_있으면_질문보다_앞에_둔다(self):
        # 모델이 배경을 먼저 읽고 질문에 답하도록 하려는 것입니다.
        prompt = advice._build_prompt("괜찮나요?", "temperature", "생후 2개월, 38.2도")
        assert prompt.index("생후 2개월") < prompt.index("질문:")

    def test_맥락이_없으면_그_자리를_비운다(self):
        prompt = advice._build_prompt("괜찮나요?", "sleep", None)
        assert "보호자가 기록한 정보" not in prompt

    def test_모르는_영역은_육아로_떨어진다(self):
        # 라우터가 먼저 400으로 막지만, 함수 단독으로도 터지지 않아야 합니다.
        assert "육아" in advice._build_prompt("질문", "없는영역", None)


class TestSystemPrompt:
    def test_진단하지_않도록_지시한다(self):
        assert "진단명을 말하지 마세요" in advice.SYSTEM_PROMPT

    def test_약_안내를_막는다(self):
        assert "약 이름" in advice.SYSTEM_PROMPT

    def test_규칙_기반_판정을_뒤집지_않도록_지시한다(self):
        # 체온 임계값은 공인 가이드라인에서 뽑은 값입니다. 모델이 이를
        # 뒤집으면 근거를 추적할 수 없게 됩니다.
        assert "판정을 뒤집지" in advice.SYSTEM_PROMPT

    def test_응급_상황을_먼저_안내하도록_지시한다(self):
        assert "3개월 미만의 발열" in advice.SYSTEM_PROMPT

    def test_고지_문구는_모델이_쓰지_않는다(self):
        # 서버가 고정 문자열로 붙입니다. 모델이 쓰면 답변마다 달라집니다.
        assert "고지 문구를 답변에 직접 쓰지 마세요" in advice.SYSTEM_PROMPT


class TestErrorMapping:
    def test_키가_없으면_503(self):
        status, detail = advice.to_http_detail(
            advice.AdviceUnavailable("키가 없습니다.")
        )
        assert status == 503
        assert detail == "키가 없습니다."

    def test_요청_초과는_429(self):
        error = anthropic.RateLimitError(
            "rate limited", response=_fake_response(429), body=None
        )
        status, detail = advice.to_http_detail(error)
        assert status == 429
        assert "잠시 후" in detail

    def test_연결_실패는_503(self):
        status, detail = advice.to_http_detail(
            anthropic.APIConnectionError(request=_fake_request())
        )
        assert status == 503

    def test_원본_오류_메시지를_사용자에게_보이지_않는다(self):
        # 내부 사정이 화면에 드러나면 안 되고, 영어 메시지도 곤란합니다.
        error = anthropic.APIStatusError(
            "invalid x-api-key", response=_fake_response(401), body=None
        )
        _, detail = advice.to_http_detail(error)
        assert "x-api-key" not in detail


class TestEndpoint:
    def test_키가_없으면_503과_안내(self, client):
        r = client.post(
            "/api/advice", json={"question": "38도인데요", "domain": "temperature"}
        )
        assert r.status_code == 503
        assert "ANTHROPIC_API_KEY" in r.json()["detail"]

    def test_모르는_영역은_400(self, client):
        r = client.post("/api/advice", json={"question": "질문", "domain": "우주"})
        assert r.status_code == 400

    def test_빈_질문은_422(self, client):
        r = client.post("/api/advice", json={"question": "", "domain": "sleep"})
        assert r.status_code == 422

    def test_너무_긴_질문은_422(self, client):
        # 프롬프트 주입과 비용 폭주를 함께 막습니다.
        r = client.post(
            "/api/advice", json={"question": "가" * 5000, "domain": "sleep"}
        )
        assert r.status_code == 422

    def test_너무_긴_맥락은_422(self, client):
        r = client.post(
            "/api/advice",
            json={"question": "질문", "domain": "sleep", "context": "가" * 9000},
        )
        assert r.status_code == 422

    def test_health가_답변_준비_상태를_알려준다(self, client):
        models = client.get("/health").json()["models"]
        assert "advice" in models
        assert models["advice"]["ready"] is False


def test_영역_목록이_앱의_AssessmentDomain과_같다():
    # lib/features/detail/assessment/assessment.dart의 enum과 맞춰야
    # 앱이 보낸 domain을 서버가 400으로 되돌리지 않습니다.
    assert set(advice.DOMAINS) == {
        "temperature",
        "feeding",
        "sleep",
        "diaper",
        "growth",
        "noise",
        "skin",
        "overall",
    }


def _fake_response(status: int):
    import httpx

    return httpx.Response(status_code=status, request=_fake_request())


def _fake_request():
    import httpx

    return httpx.Request("POST", "https://api.anthropic.com/v1/messages")
