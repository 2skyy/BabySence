"""피부 사진 보기.

**모델을 따로 학습하지 않고 Claude의 비전을 씁니다.** 상담(`advice.py`)과
같은 `ANTHROPIC_API_KEY` 하나를 씁니다.

원래는 분류 모델을 붙일 자리였습니다. 가지고 있던 학습 데이터가 성인
피부암 데이터셋(ISIC 계열 9종)이라 그만두었습니다 — 영유아에게는 거의
없는 질환들이고, 기저귀 발진 사진에 '흑색종'이 붙을 수 있었습니다.
보호자가 실제로 사진을 찍는 이유(기저귀 발진, 땀띠, 태열, 지루성 피부염)는
그 데이터에 라벨조차 없었습니다.

**암은 다루지 않습니다.** 이 기능은 병을 가려내지 않습니다. 사진에서
보이는 것을 말로 옮기고, 지금 무엇을 하면 좋을지 안내하고, 진료가 필요해
보이면 그렇게 말합니다. 진단은 하지 않습니다.

응답은 **구조화 출력**으로 스키마를 강제합니다. 모델이 JSON을 어겨서
화면이 깨지는 경로를 아예 없애려는 것입니다.
"""

import base64
import json
import logging
from typing import NamedTuple

import os
import io
import json
import base64
import logging
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from fastapi import APIRouter, UploadFile, File, HTTPException
from anthropic import Anthropic

from .config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

class SkinModelUnavailable(Exception):
    pass

class SkinModelUnavailable(RuntimeError):
    """API 키가 없거나 Claude를 부를 수 없는 상태."""
# 1. Claude API 설정
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
client = Anthropic(api_key=ANTHROPIC_API_KEY) if ANTHROPIC_API_KEY else None

# 2. 기본 클래스 라벨
DEFAULT_CLASSES = [
    "Atopic Dermatitis",
    "Contact Dermatitis",
    "Seborrheic Dermatitis",
    "Diaper Rash",
    "Infantile Eczema",
    "Urticaria",
    "normal"
]

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

class SkinModelWrapper:
    def __init__(self):
        self.model = None
        self.classes = DEFAULT_CLASSES

    def load(self):
        model_path = getattr(settings, "skin_model_path", None) or "baby_skin_mobilenet_model.pth"
        if not os.path.exists(str(model_path)):
            logger.warning("피부 모델 파일(%s)을 찾을 수 없습니다.", model_path)
            return

        try:
            checkpoint = torch.load(str(model_path), map_location='cpu')

            # state_dict 및 classes 추출
            if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
                state_dict = checkpoint["model_state_dict"]
                if "classes" in checkpoint and checkpoint["classes"]:
                    self.classes = checkpoint["classes"]
            else:
                state_dict = checkpoint

            num_classes = len(self.classes)

            # MobileNetV2 기본 구조 생성
            net = models.mobilenet_v2(weights=None)

            # [핵심] 주피터에서 학습된 classifier 구조와 일치시킴
            if "classifier.3.weight" in state_dict:
                hidden_dim = state_dict["classifier.0.weight"].shape[0]
                net.classifier = nn.Sequential(
                    nn.Linear(net.last_channel, hidden_dim),
                    nn.ReLU(inplace=True),
                    nn.Dropout(p=0.2),
                    nn.Linear(hidden_dim, num_classes)
                )
            else:
                net.classifier[1] = nn.Linear(net.last_channel, num_classes)

            # 가중치 로드
            net.load_state_dict(state_dict)
            net.eval()
            self.model = net
            logger.info("피부 분류 PyTorch 모델(.pth) 로드 성공! (클래스: %d개, 구조 자동 매핑 완료)", num_classes)
        except Exception as e:
            logger.error("피부 모델 로드 실패: %s", e)

    def predict_local(self, contents: bytes) -> tuple[str, float]:
        if not self.model:
            return "Unknown", 0.0
        try:
            img = Image.open(io.BytesIO(contents)).convert("RGB")
            tensor = transform(img).unsqueeze(0)
            with torch.no_grad():
                output = self.model(tensor)
                prob = torch.nn.functional.softmax(output[0], dim=0)
                conf, pred = torch.max(prob, 0)
                return self.classes[pred.item()], round(conf.item() * 100, 1)
        except Exception as e:
            logger.error("1차 모델 추론 오류: %s", e)
            return "Unknown", 0.0

    # [추가 2] main.py 154번 줄에서 호출하는 predict 메서드 호환
    def predict(self, image_input) -> tuple[str, float]:
        if not self.model:
            raise SkinModelUnavailable("피부 모델이 로드되지 않았습니다.")

        if isinstance(image_input, Image.Image):
            buf = io.BytesIO()
            image_input.save(buf, format="JPEG")
            return self.predict_local(buf.getvalue())
        elif isinstance(image_input, (bytes, bytearray)):
            return self.predict_local(bytes(image_input))
        elif hasattr(image_input, "file"):
            return self.predict_local(image_input.file.read())
        elif hasattr(image_input, "read"):
            return self.predict_local(image_input.read())
        else:
            return self.predict_local(bytes(image_input))

# main.py에서 호출하는 싱글톤 인스턴스
model = SkinModelWrapper()


@router.post("/diagnose")
async def diagnose_skin(file: UploadFile = File(...)):
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="업로드된 파일이 비어 있습니다.")

    # [1단계] 1차 예측
    first_prediction, first_confidence = model.predict(contents)

    # Claude API 키가 없을 경우 1차 결과 리턴
    if not client:
        return {
            "is_skin": True,
            "disease": first_prediction,
            "probability": first_confidence,
            "message": "1차 자체 모델 분석 결과입니다."
        }

    # [2단계] Claude Vision으로 책상/비피부 사진 감지 및 2차 정밀 판독
    try:
        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
        pil_img.thumbnail((800, 800))
        jpeg_buf = io.BytesIO()
        pil_img.save(jpeg_buf, format="JPEG", quality=80)
        base64_img = base64.b64encode(jpeg_buf.getvalue()).decode("utf-8")
        media_type = "image/jpeg"

        prompt = f"""
You are an expert pediatric dermatologist AI.
Analyze this baby skin image and validate the primary classification result.

Primary Model Prediction: '{first_prediction}' (Confidence: {first_confidence}%)

Tasks:
1. Check if the image is actually human/baby skin. If it's a desk, background, object, toy, or non-skin, set "is_skin": false.
2. If it is human skin, evaluate if the primary prediction is correct or adjust it based on visual evidence.
3. Provide a final disease name from [{', '.join(model.classes)}] and confidence score (0-100) with a brief medical comment in Korean.

Output ONLY a valid JSON object without markdown fences:
{{
  "is_skin": true,
  "disease": "<DISEASE_NAME>",
  "probability": 85.0,
  "message": "환부 상태 설명 및 간단한 관리 팁 (한국어)"
}}
If "is_skin" is false:
{{
  "is_skin": false,
  "disease": "None",
  "probability": 0.0,
  "message": "피부 사진이 아닙니다. 아기의 환부 부위를 정확히 다시 촬영해 주세요."
}}
"""

        response = client.messages.create(
            model="claude-sonnet-5",
            max_tokens=400,
            messages=[{
                "role": "user",
                "content": [
                    {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": base64_img}},
                    {"type": "text", "text": prompt}
                ]
            }]
        )
        logger.info("피부 분석을 준비했습니다. model=%s", settings.skin_model)

        res_text = "".join(
            block.text for block in response.content if getattr(block, "type", None) == "text"
        ).strip()

        # 마크다운 코드 블록 제거 처리
        if "```" in res_text:
            res_text = res_text.split("```")[1]
            if res_text.startswith("json"):
                res_text = res_text[4:]
            res_text = res_text.strip()

        return json.loads(res_text)
        # res_text = response.content[0].text.strip()
        # if res_text.startswith("```"):
        #     res_text = res_text.split("```")[1].replace("json", "").strip()
        #
        # return json.loads(res_text)

    except Exception as e:
        logger.error("Claude Vision 분석 중 오류: %s", e)
        raise HTTPException(status_code=500, detail=f"AI 분석 중 오류 발생: {str(e)}")
