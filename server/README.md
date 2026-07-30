# BabySense AI 서버 (FastAPI)

피부 분석 **추론만** 담당합니다. 인증과 기록 저장은 앱이 Supabase와 직접 처리하고,
분석 결과를 `skin_analyses`에 남기는 것도 앱이 합니다.
그래서 이 서버는 DB에 붙지 않고 사용자 JWT도 다루지 않습니다.

```
Flutter ──▶ Supabase   (인증, 기록 CRUD, Storage)
        └─▶ FastAPI    (이 서버 — 추론만, 상태 없음)
```

## ⚠️ 현재 동작하는 추론 엔드포인트가 없습니다

| 엔드포인트 | 상태 |
|---|---|
| `GET /health` | 동작. 모델 준비 여부를 반환합니다 |
| `POST /api/skin/diagnose` | **모델 없음 → 503** |

피부 분석은 학습된 모델이 아직 없습니다. 이전 파이썬 서버는 항상
`Atopic Dermatitis 88.4%`를 반환했지만, 고정값을 진단처럼 보여주는 것은
사용자를 오도하므로 그 동작을 가져오지 않았습니다.

즉 **지금 이 서버를 띄워도 앱에 돌려줄 결과가 없습니다.** 골격과 계약(응답 형식,
컷오프, 업로드 상한)만 준비된 상태입니다. 모델이 생기면 `app/skin.py`의
`load`/`predict`를 채우고 `SKIN_MODEL_PATH`를 지정하면 바로 동작합니다.

학습 데이터셋과 PyTorch 학습 노트북은 `~/baby_skin_data`에 있고 클래스는 9종입니다.


## 셋업

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 실행

```bash
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

`--host 0.0.0.0`이어야 같은 네트워크의 실기기에서 접근할 수 있습니다.

확인:

```bash
curl localhost:8000/health
```

## 앱에서 연결하기

앱의 기본 주소는 `lib/core/constants/api_config.dart`에 있습니다.

| 실행 환경 | 주소 |
|---|---|
| iOS 시뮬레이터 / macOS | `http://127.0.0.1:8000` (기본값) |
| Android 에뮬레이터 | `http://10.0.2.2:8000` (기본값) |
| 실기기 | 개발 PC의 LAN IP를 직접 넘겨야 합니다 |

실기기에서는 두 기본값 모두 닿지 않습니다.

```bash
flutter run --dart-define-from-file=env.json \
  --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

## 설정 (환경변수)

| 이름 | 기본값 | 설명 |
|---|---|---|
| `SKIN_MODEL_PATH` | 없음 | 피부 모델 경로. 없으면 `/api/skin/diagnose`가 503 |
| `MAX_UPLOAD_BYTES` | `52428800` (50MB) | 업로드 상한 |
| `SKIN_MIN_PROBABILITY` | `50.0` | 이 확률(%) 미만이면 진단명 대신 재촬영을 안내 |

## 응답 형식

### `POST /api/skin/diagnose`

확률이 기준 이상일 때:

```json
{ "status": "success", "disease": "Atopic Dermatitis", "probability": 88.4 }
```

기준 미만일 때 — 앱은 `status`를 보고 진단명 대신 `message`를 보여줍니다
(`skin_analysis_page.dart`에 구현되어 있습니다):

```json
{
  "status": "low_confidence",
  "disease": "Atopic Dermatitis",
  "probability": 41.2,
  "message": "정확한 판독이 어렵습니다. 깨끗한 조명에서 환부를 다시 촬영해 주세요."
}
```

`disease`에는 모델이 낸 **원본 라벨**을 넣습니다. 한글 변환은 앱이 담당합니다
(모델을 교체해도 DB에 쌓인 과거 이력이 깨지지 않게 하려는 것입니다).

### 오류

| 코드 | 상황 |
|---|---|
| 400 | 빈 파일 |
| 413 | 업로드 상한 초과 |
| 503 | 모델이 준비되지 않음 |
