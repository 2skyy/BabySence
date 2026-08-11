"""Claude로 육아 질문에 답하는 모듈.

**앱이 아니라 서버에서 부릅니다.** Flutter에 API 키를 넣으면 앱 패키지를
뜯어 키를 꺼낼 수 있습니다. 키는 서버 환경변수에만 둡니다.

역할을 좁게 잡았습니다. 진단하지 않고, 규칙 기반 판정을 대신하지도 않습니다.
체온 임계값 같은 판정은 앱의 규칙 엔진이 이미 내놓았고, 여기서는 그 판정을
**맥락으로 받아** 보호자의 질문에 설명과 행동 안내를 덧붙일 뿐입니다.
"""

import logging

from anthropic import (
    Anthropic,
    APIConnectionError,
    APIStatusError,
    RateLimitError,
)

from .config import settings

logger = logging.getLogger(__name__)

#: 답변에 항상 따라붙는 고지. 앱의 MedicalDisclaimer와 같은 취지입니다.
#: 모델이 문구를 지어내면 화면마다 달라지므로, 서버가 고정 문자열로 붙입니다.
DISCLAIMER = (
    "이 안내는 참고용이며 의사의 진단을 대신하지 않습니다. "
    "아이 상태가 걱정되면 소아과 진료를 받아 주세요."
)

#: 질문할 수 있는 영역. 앱의 AssessmentDomain과 이름을 맞춥니다.
DOMAINS = {
    "temperature": "체온·발열",
    "feeding": "수유",
    "sleep": "수면",
    "diaper": "배변",
    "growth": "성장",
    "noise": "수면 환경 소음",
    "skin": "피부",
    "overall": "종합",
}

SYSTEM_PROMPT = """당신은 영유아를 키우는 보호자를 돕는 육아 정보 도우미입니다.
BabySense 앱 안에서 동작하며, 보호자가 기록한 데이터를 맥락으로 받습니다.

## 역할의 경계

- 당신은 의료진이 아니고, 이 앱은 의료기기가 아닙니다.
- 진단명을 말하지 마세요. 질병을 특정하거나 배제하지 마세요.
- 약 이름, 용량, 복용법을 안내하지 마세요.
- 앱이 이미 낸 판정(정상/주의/상담 권장)이 함께 주어지면 그 판정을 뒤집지
  마세요. 판정은 공인 가이드라인에서 뽑은 임계값으로 계산한 것입니다.
  당신은 그 판정이 무엇을 뜻하는지 풀어 설명하고 무엇을 하면 좋을지 돕습니다.

## 답변 방식

- 한국어로, 보호자가 읽기 쉬운 말로 씁니다. 의학 용어는 풀어 씁니다.
- 결론을 먼저 말하고 이유를 뒤에 붙입니다.
- 3~5문장으로 짧게. 목록은 항목이 셋 이상일 때만 씁니다.
- 지금 할 수 있는 구체적인 행동을 알려주세요.
  ("수분을 충분히 주세요"처럼 실행할 수 있는 것)
- 모르면 모른다고 말하세요. 지어내지 마세요.
- 맥락으로 받은 기록에 없는 수치를 사실인 것처럼 말하지 마세요.

## 반드시 병원으로 안내해야 하는 경우

아래에 해당하면 다른 조언보다 먼저, 분명하게 진료를 권하세요.

- 생후 3개월 미만의 발열
- 경련, 의식이 흐림, 숨쉬기 힘들어함, 심한 늘어짐
- 탈수 징후(소변이 거의 없음, 입술이 마름, 울어도 눈물이 없음)
- 보호자가 "평소와 확실히 다르다"고 느끼는 상태

## 하지 않는 것

- 안심시키려고 위험 신호를 축소하지 마세요.
- 고지 문구를 답변에 직접 쓰지 마세요. 앱이 따로 붙입니다.
"""


class AdviceUnavailable(RuntimeError):
    """API 키가 없거나 Claude를 부를 수 없는 상태."""


class _AdviceClient:
    """Claude 클라이언트. 키가 없으면 만들지 않습니다."""

    def __init__(self) -> None:
        self._client: Anthropic | None = None

    def load(self) -> None:
        if not settings.anthropic_api_key:
            logger.warning(
                "ANTHROPIC_API_KEY가 없습니다. /api/advice는 503을 반환합니다."
            )
            return
        self._client = Anthropic(api_key=settings.anthropic_api_key)
        logger.info("Claude 클라이언트를 준비했습니다. model=%s", settings.advice_model)

    @property
    def ready(self) -> bool:
        return self._client is not None

    def ask(self, question: str, domain: str, context: str | None = None) -> str:
        """질문에 답합니다. 준비되지 않았으면 AdviceUnavailable을 던집니다."""
        if self._client is None:
            raise AdviceUnavailable(
                "답변 기능이 설정되지 않았습니다. 서버에 ANTHROPIC_API_KEY가 필요합니다."
            )

        prompt = _build_prompt(question, domain, context)

        # 길어질 수 있는 답변이라 스트리밍으로 받습니다. 논스트리밍은 큰
        # max_tokens에서 HTTP 타임아웃에 걸립니다.
        with self._client.messages.stream(
            model=settings.advice_model,
            max_tokens=1024,
            system=SYSTEM_PROMPT,
            # 육아 질문은 대개 짧고 즉답형이라 낮은 effort로 충분합니다.
            # 답이 얕으면 medium으로 올리세요.
            output_config={"effort": "low"},
            messages=[{"role": "user", "content": prompt}],
        ) as stream:
            message = stream.get_final_message()

        # 안전 분류기가 거절하면 content가 비어 있습니다. 먼저 확인하지 않으면
        # content[0]에서 터집니다.
        if message.stop_reason == "refusal":
            logger.info("모델이 답변을 거절했습니다. domain=%s", domain)
            raise AdviceUnavailable(
                "이 질문에는 답변할 수 없습니다. 소아과 진료를 받아 주세요."
            )

        return "".join(
            block.text for block in message.content if block.type == "text"
        ).strip()


def _build_prompt(question: str, domain: str, context: str | None) -> str:
    """사용자 질문과 앱이 보낸 맥락을 하나의 프롬프트로 만듭니다.

    맥락(아이 개월 수, 최근 기록, 앱이 낸 판정)은 앱이 조립해 보냅니다.
    서버는 DB에 붙지 않으므로 여기서 기록을 조회하지 않습니다.
    """
    label = DOMAINS.get(domain, "육아")
    parts = [f"영역: {label}"]

    if context:
        parts.append(f"\n보호자가 기록한 정보:\n{context}")

    parts.append(f"\n질문: {question}")
    return "\n".join(parts)


client = _AdviceClient()


def to_http_detail(error: Exception) -> tuple[int, str]:
    """예외를 (상태코드, 사용자에게 보여줄 문구)로 바꿉니다.

    Claude의 원본 오류 메시지를 그대로 내보내지 않습니다. 내부 사정이
    사용자 화면에 드러나고, 한국어도 아닙니다.
    """
    if isinstance(error, AdviceUnavailable):
        return 503, str(error)
    if isinstance(error, RateLimitError):
        return 429, "요청이 많습니다. 잠시 후 다시 시도해 주세요."
    if isinstance(error, APIConnectionError):
        return 503, "답변 서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요."
    if isinstance(error, APIStatusError):
        logger.error("Claude 오류 %s: %s", error.status_code, error.message)
        return 502, "답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요."
    logger.exception("답변 생성 중 예상치 못한 오류")
    return 500, "답변을 만들지 못했습니다."
