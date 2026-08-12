# BabySense AI 서버 (FastAPI)

**추론과 답변 생성만** 담당합니다. 기록 저장은 앱이 Supabase와 직접 처리하고,
분석 결과를 `skin_analyses`에 남기는 것도 앱이 합니다. 그래서 이 서버는 DB에
붙지 않습니다.

다만 `/api/advice`는 요청마다 Claude 크레딧을 쓰므로, **앱이 보낸 Supabase
액세스 토큰이 유효한지만** 확인합니다(아래 참고). 그 밖의 인증·인가는 여전히
Supabase가 앱과 직접 처리합니다.

```
Flutter ──▶ Supabase   (인증, 기록 CRUD, Storage)
        └─▶ FastAPI    (이 서버 — 추론·답변, 상태 없음)
                └─▶ Claude API   (육아 질문 답변)
```

## 엔드포인트 상태

| 엔드포인트 | 상태 |
|---|---|
| `GET /health` | 동작. 기능별 준비 여부를 반환합니다 |
| `POST /api/advice` | **로그인 필요.** 키가 없거나 Supabase 설정이 없으면 503 |
| `POST /api/skin/diagnose` | **모델 없음 → 503** |

### 피부 분석 — 모델 없음

학습된 모델이 아직 없습니다. 이전 파이썬 서버는 항상 `Atopic Dermatitis 88.4%`를
반환했지만, 고정값을 진단처럼 보여주는 것은 사용자를 오도하므로 그 동작을
가져오지 않았습니다.

골격과 계약(응답 형식, 컷오프, 업로드 상한)만 준비된 상태입니다. 모델이 생기면
`app/skin.py`의 `load`/`predict`를 채우고 `SKIN_MODEL_PATH`를 지정하면 바로
동작합니다. 학습 데이터셋과 PyTorch 학습 노트북은 `~/baby_skin_data`에 있고
클래스는 9종입니다.

### 육아 질문 답변 — Claude

> 🔑 **API 키는 이 서버에만 둡니다. 앱에 넣지 마세요.**
> Flutter 앱에 키를 넣으면 패키지를 뜯어 꺼낼 수 있습니다. 그래서 앱은
> Claude를 직접 부르지 않고 항상 이 서버를 거칩니다.

설정은 `server/.env`에 둡니다(`.gitignore`로 막혀 있습니다). `app/config.py`가
읽으므로 따로 `export` 하지 않아도 됩니다.

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

키가 없어도 서버는 정상 기동하고, `/api/advice`만 503을 반환합니다.

#### 로그인한 사용자만 부를 수 있습니다

요청 한 번마다 Claude 크레딧이 나갑니다. 인증이 없으면 서버 주소를 아는
누구나 무제한으로 태울 수 있어, 앱이 보낸 Supabase 액세스 토큰을 확인합니다.

```
Authorization: Bearer <Supabase access token>
```

토큰 검증은 **Supabase에 물어봅니다**(`GET /auth/v1/user`). 이 프로젝트의
토큰은 ES256(비대칭)이라 서명을 직접 확인하려면 JWKS를 받아 캐시하고 키
회전까지 따라가야 합니다. 같은 토큰은 60초 캐시해 대화 중 매 턴 왕복하지
않습니다.

`SUPABASE_URL`이 없거나 Supabase에 닿지 못하면 **막습니다**(503). 설정을
빠뜨렸을 때 조용히 인증 없는 서버가 되는 쪽이 훨씬 나쁩니다.

`SUPABASE_PUBLISHABLE_KEY`는 앱에도 들어 있는 공개 값입니다.
**`service_role` 키를 넣지 마세요** — 그 키는 RLS를 우회합니다.

#### 횟수 상한

로그인만으로는 총액이 막히지 않습니다. 계정은 얼마든지 새로 만들 수 있어
사용자별 상한과 서버 전체 상한을 함께 둡니다. 상한은 모델을 부르기 **전에**
봅니다 — 부른 뒤에 세면 이미 돈이 나갑니다.

| 환경변수 | 기본값 | 뜻 |
|---|---|---|
| `ADVICE_RATE_LIMIT` | 30 | 사용자 한 명이 창 하나 안에 부를 수 있는 횟수 |
| `ADVICE_GLOBAL_RATE_LIMIT` | 300 | 서버 전체 상한 |
| `ADVICE_RATE_WINDOW_SECONDS` | 3600 | 창 길이(초) |

**한 프로세스 안에서만 셉니다.** 워커를 여러 개 띄우면 각자 따로 세므로 실제
상한은 그 배수가 됩니다. 늘릴 때는 Redis 같은 공용 저장소가 필요합니다.

#### 답변이 끊기는 경우

`ADVICE_MAX_TOKENS`(기본 4096)는 **추론과 본문이 함께 쓰는 상한**입니다.
`claude-opus-5`는 `thinking`을 넘기지 않으면 적응형 추론이 켜지므로
(생략하면 추론이 꺼지던 Opus 4.8/4.7과 반대) 여유를 둡니다. 추론을 끄는 쪽은
일부러 피했습니다 — 이 모델은 추론을 끄면 `<thinking>` 태그가 답변에 새어
나오는 일이 있습니다. 비용은 `effort: low`로 낮춥니다.

상한에 걸리면 `stop_reason`이 `max_tokens`가 됩니다.

- 본문이 남아 있으면 `truncated: true`로 내려보내고 앱이 "여기서 끊겼어요"를
  덧붙입니다. 끊긴 답을 완성된 답처럼 두면 잘린 문장이 결론으로 읽힙니다.
- 추론이 상한을 다 써 본문이 비면 503으로 막습니다. 빈 말풍선을 띄우지
  않으려는 것입니다.

#### CORS

기본값은 **아무 출처도 허용하지 않음**입니다. 모바일 앱은 `Origin`을 보내지
않아 영향이 없습니다. 브라우저에서 부를 일이 생기면 `CORS_ORIGINS`에 그
주소만 적으세요(쉼표로 구분).

**역할을 좁게 잡았습니다.** 진단하지 않고, 규칙 기반 판정을 대신하지도
않습니다. 체온 임계값 같은 판정은 앱의 규칙 엔진이 이미 내놓았고, 여기서는
그 판정을 **맥락으로 받아** 보호자의 질문에 설명을 덧붙일 뿐입니다.
시스템 프롬프트는 `app/advice.py`에 있으며 다음을 금지합니다.

- 진단명을 말하는 것
- 약 이름·용량·복용법을 안내하는 것
- 앱이 낸 판정을 뒤집는 것

반대로 생후 3개월 미만 발열, 경련, 탈수 징후 등은 **다른 조언보다 먼저**
진료를 권하도록 지시합니다.

고지 문구(`disclaimer`)는 **서버가 고정 문자열로 붙입니다.** 모델이 쓰게 두면
답변마다 문구가 달라집니다.

**맥락은 앱이 조립해 보냅니다.** 이 서버는 DB에 붙지 않아 기록을 직접 조회할
수 없습니다. 앱의 `buildAdviceContext()`가 개월 수·판정·최근 기록을 문장으로
만들며, **아이 이름이나 아이디는 넣지 않습니다**(외부로 나가는 개인정보를
줄이려는 것입니다).


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
| `ANTHROPIC_API_KEY` | 없음 | Claude 키. 없으면 `/api/advice`가 503. **앱에 넣지 마세요** |
| `ADVICE_MODEL` | `claude-opus-5` | 답변에 쓸 모델 |
| `MAX_QUESTION_CHARS` | `500` | 질문 길이 상한. 프롬프트 주입과 비용 폭주를 함께 막습니다 |
| `MAX_CONTEXT_CHARS` | `2000` | 앱이 보내는 맥락의 길이 상한 |

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

### `POST /api/advice`

요청 — `domain`은 앱의 `AssessmentDomain` enum 이름과 같습니다
(`temperature` / `feeding` / `sleep` / `diaper` / `growth` / `noise` / `skin` / `overall`).

```json
{
  "question": "38.2도인데 병원에 가야 할까요?",
  "domain": "temperature",
  "context": "- 생후 2개월\n- 앱 판정: 체온 상담 권장 (기준 버전 temperature-2026-07-30)"
}
```

응답 — `disclaimer`는 서버가 붙인 고정 문구입니다. 앱은 답변과 함께 반드시
보여줍니다.

```json
{
  "status": "success",
  "answer": "생후 2개월에 38.2도는 바로 진료를 받아야 하는 상황입니다. ...",
  "disclaimer": "이 안내는 참고용이며 의사의 진단을 대신하지 않습니다. ..."
}
```

### 오류

| 코드 | 상황 |
|---|---|
| 400 | 빈 파일 / 알 수 없는 `domain` |
| 413 | 업로드 상한 초과 |
| 422 | 질문이 비었거나 길이 상한 초과 |
| 429 | Claude 요청 한도 초과 |
| 502 | Claude 오류 (원본 메시지는 로그에만 남기고 사용자에게는 보이지 않습니다) |
| 503 | 모델 또는 API 키가 준비되지 않음 |

## 테스트

```bash
cd server && source venv/bin/activate
python -m pytest tests -q
```

API 키 없이 확인할 수 있는 부분(프롬프트 조립, 입력 검증, 오류 매핑)만
다룹니다. **실제 답변 품질과 거절 처리는 키가 있어야 확인할 수 있습니다.**
