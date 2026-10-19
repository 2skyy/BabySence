"""홈의 상담 단추(챗봇)에 쓸 로고를 앱 아이콘에서 만듭니다.

앱 아이콘은 흰 선화에 **밝은 민트 배경**입니다(#9BE6B8 언저리). 그대로
동그란 단추로 쓰면 두 가지가 어긋납니다.

1. 홈의 다른 강조 요소는 진한 세이지(`AppColors.primary` #4F7A60)라
   이 단추만 혼자 밝게 떠 보입니다.
2. 밝은 민트 위의 흰 선이라 **선과 배경 대비가 1.35:1**입니다. 선이
   사실상 안 보입니다.

배경만 어둡게 내리고 흰 선은 그대로 둡니다. 색상(hue)은 건드리지
않습니다 — 재 보니 로고가 140°, 앱 강조색이 144°로 이미 거의 같고,
어긋난 것은 밝기였습니다(로고 V=0.94, 강조색 V=0.48).

**채도로 갈라 밝기를 다르게 적용합니다.** 흰 선은 채도가 0에 가까워
어둡게 하지 않고, 유채색 배경만 낮춥니다. 선을 오려내지 않으므로
발광 효과와 부드러운 가장자리가 그대로 남습니다.

결과: 배경 #557361 (강조색 #4F7A60과 거의 같음), 대비 3.34:1.

    python3 tool/make_chat_logo.py

원본 로고가 바뀌면 이것을 다시 돌리세요.
"""

import numpy as np
from PIL import Image

SRC = "assets/icon/app_icon.png"
DST = "assets/icon/chat_logo.png"

# 배경을 얼마나 남길지 / 채도를 얼마나 줄일지.
VALUE_SCALE = 0.50
SAT_SCALE = 0.78

# 이 채도 아래는 '흰 선'으로 보고 밝기를 유지합니다.
LINE_SAT = 0.22


def main() -> None:
    src = np.asarray(Image.open(SRC).convert("RGB"), float) / 255.0

    mx, mn = src.max(2), src.min(2)
    value = mx
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)

    # 채도가 낮을수록 1에 가까워집니다(=선). 그만큼 원래 밝기를 지킵니다.
    line = np.clip((LINE_SAT - sat) / LINE_SAT, 0, 1)
    scale = VALUE_SCALE + (1.0 - VALUE_SCALE) * line

    v2 = np.clip(value * scale, 0, 1)
    s2 = np.clip(sat * SAT_SCALE, 0, 1)

    # 채널 사이의 상대 위치를 유지해 색상을 보존합니다.
    mn2 = v2 * (1 - s2)
    spread = np.maximum(mx - mn, 1e-6)
    out = np.empty_like(src)
    for c in range(3):
        out[..., c] = mn2 + (src[..., c] - mn) / spread * (v2 - mn2)

    Image.fromarray((np.clip(out, 0, 1) * 255).astype("uint8")).save(DST)
    print(f"{DST} 저장")


if __name__ == "__main__":
    main()
