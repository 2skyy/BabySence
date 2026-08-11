"""서버 설정. 모두 환경변수로 덮어쓸 수 있습니다."""

import os
from pathlib import Path

# 이 파일 기준 server/ 디렉터리
SERVER_DIR = Path(__file__).resolve().parent.parent


def _path_from_env(name: str, default: str | None) -> Path | None:
    raw = os.getenv(name, default)
    if not raw:
        return None
    path = Path(raw).expanduser()
    # 상대 경로는 server/ 기준으로 봅니다. 실행 위치에 따라 달라지지 않게 하려는 것입니다.
    return path if path.is_absolute() else (SERVER_DIR / path)


class Settings:
    #: 피부 질환 분류 모델 경로. 아직 학습된 모델이 없어 기본값이 없습니다.
    #: 저장소에는 모델 파일을 넣지 않습니다(용량, 이력 오염).
    skin_model_path: Path | None = _path_from_env("SKIN_MODEL_PATH", None)

    #: 업로드 상한(바이트). Spring에서 50MB로 올려뒀던 값을 따릅니다.
    max_upload_bytes: int = int(os.getenv("MAX_UPLOAD_BYTES", 50 * 1024 * 1024))

    #: 이 확률(%)에 못 미치면 진단명을 내놓지 않고 재촬영을 안내합니다.
    #: 오진을 막기 위한 기준이며, Spring 서버에서 쓰던 값과 같습니다.
    skin_min_probability: float = float(os.getenv("SKIN_MIN_PROBABILITY", 50.0))

    #: Claude API 키. **앱에 넣지 마세요.** 앱 패키지는 뜯을 수 있습니다.
    #: 없으면 /api/advice가 503을 반환하고 나머지 기능은 그대로 동작합니다.
    anthropic_api_key: str | None = os.getenv("ANTHROPIC_API_KEY")

    #: 답변에 쓸 모델.
    advice_model: str = os.getenv("ADVICE_MODEL", "claude-opus-5")

    #: 질문 길이 상한(자). 프롬프트 주입과 비용 폭주를 함께 막습니다.
    max_question_chars: int = int(os.getenv("MAX_QUESTION_CHARS", 500))

    #: 앱이 함께 보내는 맥락(기록 요약)의 길이 상한(자).
    max_context_chars: int = int(os.getenv("MAX_CONTEXT_CHARS", 2000))

    #: 대화에서 서버가 받아 주는 최대 메시지 수(사용자+답변 합계).
    #: 이 서버는 대화를 저장하지 않고 앱이 매번 전체를 보냅니다. 상한이 없으면
    #: 대화가 길어질수록 요청과 비용이 무한정 커집니다.
    max_chat_messages: int = int(os.getenv("MAX_CHAT_MESSAGES", 40))


settings = Settings()
