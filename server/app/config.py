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


settings = Settings()
