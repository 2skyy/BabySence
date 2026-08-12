"""서버 설정. 모두 환경변수로 덮어쓸 수 있습니다."""

import os
from pathlib import Path

from dotenv import load_dotenv

# 이 파일 기준 server/ 디렉터리
SERVER_DIR = Path(__file__).resolve().parent.parent

# server/.env를 읽습니다. 이미 환경변수로 준 값은 덮어쓰지 않습니다.
#
# 예전에는 이 파일이 있어도 아무도 읽지 않아, 실행할 때마다 export를 해야
# 했습니다. 필요한 값이 하나뿐일 때는 넘어갔지만 이제 셋이라 빠뜨리기 쉽습니다.
load_dotenv(SERVER_DIR / ".env", override=False)


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

    #: Supabase 프로젝트 주소. /api/advice를 부른 사람이 로그인한 사용자인지
    #: 확인할 때 씁니다. 없으면 /api/advice가 503을 반환합니다 —
    #: 인증 없이 열어 두면 서버 주소를 아는 누구나 크레딧을 태울 수 있습니다.
    supabase_url: str | None = os.getenv("SUPABASE_URL")

    #: Supabase publishable 키. 공개되는 값이라 서버에 두어도 됩니다
    #: (앱에도 같은 값이 들어 있습니다). service_role 키를 넣지 마세요 —
    #: 그 키는 RLS를 우회합니다.
    supabase_publishable_key: str | None = os.getenv("SUPABASE_PUBLISHABLE_KEY")

    #: 답변에 쓸 모델.
    advice_model: str = os.getenv("ADVICE_MODEL", "claude-opus-5")

    #: 답변 한 번의 토큰 상한.
    #:
    #: claude-opus-5는 thinking 파라미터를 생략하면 **적응형 추론이 켜집니다**
    #: (Opus 4.8/4.7과 반대). 그리고 이 값은 추론과 본문의 **공통 상한**이라,
    #: 추론이 많이 쓰면 답이 중간에 끊깁니다. 3~5문장짜리 답변이지만
    #: 여유를 둡니다.
    advice_max_tokens: int = int(os.getenv("ADVICE_MAX_TOKENS", 4096))

    #: 사용자 한 명이 창 하나(초) 안에 부를 수 있는 횟수.
    advice_rate_limit: int = int(os.getenv("ADVICE_RATE_LIMIT", 30))
    advice_rate_window_seconds: int = int(
        os.getenv("ADVICE_RATE_WINDOW_SECONDS", 3600)
    )

    #: 서버 전체 상한. 사용자별 상한만으로는 총액이 막히지 않습니다 —
    #: 계정은 얼마든지 새로 만들 수 있기 때문입니다.
    advice_global_rate_limit: int = int(os.getenv("ADVICE_GLOBAL_RATE_LIMIT", 300))

    #: 브라우저에서 부를 출처. 비워 두면 CORS 헤더를 아예 붙이지 않습니다.
    #: 모바일 앱은 Origin을 보내지 않으므로 이 값과 무관하게 동작합니다.
    cors_origins: list[str] = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "").split(",")
        if origin.strip()
    ]

    #: 질문 길이 상한(자). 프롬프트 주입과 비용 폭주를 함께 막습니다.
    max_question_chars: int = int(os.getenv("MAX_QUESTION_CHARS", 500))

    #: 앱이 함께 보내는 맥락(기록 요약)의 길이 상한(자).
    max_context_chars: int = int(os.getenv("MAX_CONTEXT_CHARS", 2000))

    #: 대화에서 서버가 받아 주는 최대 메시지 수(사용자+답변 합계).
    #: 이 서버는 대화를 저장하지 않고 앱이 매번 전체를 보냅니다. 상한이 없으면
    #: 대화가 길어질수록 요청과 비용이 무한정 커집니다.
    max_chat_messages: int = int(os.getenv("MAX_CHAT_MESSAGES", 40))


settings = Settings()
