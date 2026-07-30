"""피부 질환 분류.

**아직 학습된 모델이 없습니다.**

이전 파이썬 서버(~/baby_skin_data/main.py)는 이미지를 열기만 하고 항상
`{"disease": "Atopic Dermatitis", "probability": 88.4}`를 반환했습니다.
아기 피부 질환을 판단하는 화면에서 고정값을 진단처럼 보여주는 것은
사용자를 오도하므로 그 동작을 옮겨오지 않았습니다.

모델이 준비되면 `load_model` / `predict`만 채우면 됩니다.
학습 데이터셋과 PyTorch 학습 노트북은 ~/baby_skin_data 에 있고
클래스는 9종입니다(Atopic Dermatitis, Melanoma, ... ).
"""

import logging

from .config import settings

logger = logging.getLogger(__name__)


class SkinModelUnavailable(RuntimeError):
    """학습된 피부 모델이 없는 상태."""


class _SkinModel:
    def __init__(self) -> None:
        self._model = None

    def load(self) -> None:
        path = settings.skin_model_path
        if path is None:
            logger.warning(
                "피부 모델이 설정되지 않았습니다. /api/skin/diagnose는 503을 반환합니다. "
                "학습된 모델이 준비되면 SKIN_MODEL_PATH를 지정하세요."
            )
            return

        if not path.exists():
            logger.warning("피부 모델 파일을 찾을 수 없습니다: %s", path)
            return

        # TODO: 학습된 모델을 불러오는 코드. 예: torch.load(path) 후 eval()
        logger.warning(
            "피부 모델 파일(%s)은 있지만 불러오는 코드가 아직 없습니다.", path
        )

    @property
    def is_ready(self) -> bool:
        return self._model is not None

    def predict(self, image_bytes: bytes) -> tuple[str, float]:
        """(질환 라벨, 확률 0~100)을 돌려줘야 합니다.

        라벨은 한글로 바꾸지 않고 모델이 낸 원본을 그대로 씁니다.
        한글 변환은 앱이 담당합니다(모델을 교체해도 과거 이력이 깨지지 않게).
        """
        raise SkinModelUnavailable(
            "피부 분석 모델이 아직 준비되지 않았습니다. "
            "학습된 모델을 SKIN_MODEL_PATH로 지정해야 합니다."
        )


model = _SkinModel()
