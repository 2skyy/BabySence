# 논문 수정 문안 — 4차(전제내용수정본) 대조 결과

2026-08-17. `영유아_상태_입력_기반_AI_의사결정_지원_플랫폼_연구_JDCS투고본.docx`(4차)를
현재 코드와 문단 단위로 대조하여 **사실관계가 어긋나는 곳만** 정리했습니다.
논지·구조·인용은 건드리지 않았습니다.

각 항목은 **현재 → 수정** 형태이고, 국·영문이 쌍으로 된 절(3-4)은 영문도 함께
적었습니다. HWP/Word에 그대로 붙여 넣을 수 있습니다.

> **먼저 확인하실 것**: 9번(3-5절)은 문단을 통째로 바꾸는 것이라 서사가 달라집니다.
> "자체 CNN을 두려 했으나 산출 형태가 책임 범위와 충돌해 폐기했다"는 틀로 썼는데,
> 이 설명이 의도와 맞는지 봐 주세요. 나머지 여덟 개는 숫자·시제 교정 수준입니다.

---

## 요약

| # | 위치 | 무엇이 틀렸나 |
|---|---|---|
| 1 | 국문·영문 초록 | 피부를 '분류 모델'이라 함 |
| 2 | 1-2 ② | 소셜 로그인을 구현 완료로 서술 |
| 3 | 표 1 | 본 연구 행에 `CNN` |
| 4 | 3-2 ②③④ | 수유·수면·배변을 판정 대상으로 서술 |
| 5 | 3-2 ⑨ | 백색소음 음량 자동 제한 — 미구현 |
| 6 | 3-3 | 판정 지표 여섯 개 나열 |
| 7 | 3-4 (a) | 소셜 로그인·FCM 완료 시제 |
| 8 | 3-4 (b) | FastAPI가 기록 입력값을 검증한다고 서술 |
| 9 | 3-4 (c) · 3-5 | **피부를 자체 CNN·외부 API 미호출로 서술** ← 가장 큰 것 |
| 10 | 3-4 (d) | 테이블 14개, 이미지 Storage 보관, 소셜·FCM |
| 11 | 3-7 | 소셜 로그인 완료 시제 |
| 12 | 3-8 셋째 | '신뢰도가 기준에 미치지 못할 경우' — 확률을 반환하지 않음 |

---

## 1. 국문 초록

**현재**

> …여기에 외부 LLM 기반 행동 가이드 생성과 **피부 이미지 분류 모델**을 결합한
> 통합 아키텍처(Flutter, FastAPI, Supabase)로 구성하였다.

**수정**

> …여기에 외부 LLM 기반 행동 가이드 생성과 **피부 이미지 해석 모듈**을 결합한
> 통합 아키텍처(Flutter, FastAPI, Supabase)로 구성하였다.

## 1-2. 영문 초록

**현재**

> …combined with an external large language model for generating action guides and
> **a skin image classification model**, within an integrated architecture…

**수정**

> …combined with an external large language model for generating action guides and
> **an image-based skin observation module**, within an integrated architecture…

*이유: 병명을 분류하지 않습니다. 관찰 서술과 2단계 안내만 반환합니다.*

---

## 2. 1-2 연구 방법 및 범위 — ②

**현재**

> …**카카오·구글·애플 간편 로그인**과 규칙 알고리즘 및 외부 LLM API 연동 모듈을
> 결합한 통합 아키텍처를 구현한다.

**수정**

> …**소셜 로그인 연동 구조**와 규칙 알고리즘 및 외부 LLM API 연동 모듈을 결합한
> 통합 아키텍처를 구현한다.

*이유: 앱 코드와 딥링크 설정은 완비했으나 인증 제공자 등록이 남아 있어, 현재
동작하는 것은 이메일 로그인입니다.*

---

## 3. 표 1 — 본 연구 행

**현재**

> 공인 지침 기반 규칙 엔진 + LLM + **CNN**

**수정**

> 공인 지침 기반 규칙 엔진 + LLM(행동 가이드·피부 이미지 해석)

---

## 4. 3-2 기능 — ②③④

세 항목 모두 '판단·분석'으로 적혀 있으나, 현재 판정 규칙이 구현된 지표는
체온·성장·수면 환경 소음 셋입니다. 아래처럼 **기록·추이 확인**으로 바꾸고,
판정을 두지 않은 이유를 ④ 뒤에 한 문장 덧붙이시길 권합니다.

**현재 (②)**

> 수유량, 수유 시간, 수유 방식 등의 데이터를 기반으로 수유 패턴을 분석하고
> **이상 여부를 판단한다.**

**수정 (②)**

> 수유량, 수유 시간, 수유 방식 등의 데이터를 입력받아 수유 패턴과 그 변화 추이를
> 제시한다.

**현재 (③)**

> 수면 시간, 낮잠 횟수, 각성 횟수를 입력받아 수면 패턴의 변화 및 **이상 여부를
> 분석한다.**

**수정 (③)**

> 수면 시간, 낮잠 횟수, 각성 횟수를 입력받아 수면 패턴의 변화 추이를 제시한다.

**현재 (④)**

> 배변 횟수, 소변 횟수, 배변 상태 등을 기반으로 **배변 및 수분 상태를 판단한다.**

**수정 (④) — 뒤 문장 추가**

> 배변 횟수, 소변 횟수, 배변 상태 등을 입력받아 배변 및 수분 상태의 변화 추이를
> 제시한다. 수유·수면·배변 세 지표에 3단계 판정을 두지 않은 것은 의도된 설계이다.
> 본 연구는 판정의 근거를 공인 지침으로 한정하였는데, 이 세 지표는 정상 범위를
> 연령별 임계값으로 제시한 국내 공인 자료를 확보하지 못하였다. 근거 없이 판정을
> 생성하는 것은 판단 근거의 추적 가능성이라는 본 연구의 전제와 충돌하므로, 해당
> 지표는 기록과 추이 제시에 한정하였다.

---

## 5. 3-2 기능 — ⑨ (백색 소음)

**현재** (해당 부분만)

> …보호자가 측정 버튼을 누르면 시스템은 아기 수면 공간의 현재 소음도를 측정하여
> 다른 기능과 동일한 3단계 구조(정상 / 주의 / 상담 권장)로 판정하고(3-3절 참조),
> **백색 소음 재생 중에는 재생 음량과 주변 소음이 합산된 실측값이 기준을 넘지
> 않도록 최대 음량을 자동으로 제한한다.** 또한 측정값이 높게 나올 경우…

**수정**

> …보호자가 측정 버튼을 누르면 시스템은 아기 수면 공간의 현재 소음도를 측정하여
> 정상 / 주의 / 개선 권장의 3단계로 판정한다(3-3절 참조). 측정값이 높게 나올 경우…

*이유 둘. (가) 음량 자동 제한은 아직 구현하지 않았습니다. (나) 소음은 의료기관
방문 사유가 아니므로 세 번째 단계를 '상담 권장'이 아니라 '개선 권장'으로 두었고,
코드도 그렇게 되어 있습니다.*

> 음량 자동 제한을 향후 과제로 남기시려면 3-2⑨ 끝이나 5장에 이렇게 덧붙이십시오:
> "재생 음량과 주변 소음이 합산된 실측값을 기준으로 최대 음량을 자동 제한하는
> 기능은 향후 구현 과제로 남는다."

---

## 6. 3-3 규칙 기반 판단 기준

**현재**

> 판정은 지표를 하나로 합산하지 않고 지표별로 독립하여 수행한다. **체온, 성장,
> 수면, 수유, 배변, 수면 환경 소음은** 각각 근거가 되는 지침이 다르므로…

**수정**

> 판정은 지표를 하나로 합산하지 않고 지표별로 독립하여 수행한다. **체온, 성장,
> 수면 환경 소음은** 각각 근거가 되는 지침이 다르므로…

*뒤에 이어지는 NICE 신호등 체계 설명과 "수유 저하·소변량 감소가 황색 징후에
포함된다"는 문장은 그대로 두셔도 됩니다. 그 대목은 수집하는 기록과의 대응을
말하는 것이지 판정을 말하는 것이 아니기 때문입니다.*

같은 절 끝의 수면·수유 기준 서술도 손봐야 합니다.

**현재**

> 수면 권장 시간은 대한소아과학회가 제공하는 영유아 육아정보에서 제시하는 연령별
> 수면 시간(신생아 하루 약 16~17시간 등)을 기준으로 하였다[30]. 수유 권장 횟수는
> 질병관리청 국가건강정보포털이 제시하는 모유 수유 지침의 하루 8~12회 기준을
> 참고하였다[31].

**수정**

> 수면과 수유는 대한소아과학회의 연령별 권장 수면 시간[30]과 질병관리청의 모유
> 수유 지침[31]을 화면의 참고 정보로 함께 제시하되, 이를 판정 임계값으로는 사용하지
> 않았다. 두 자료는 권장 범위를 제시할 뿐 정상과 이상을 가르는 연령별 경계를
> 규정하지 않기 때문이다.

---

## 7. 3-4 (a) 클라이언트 계층

**현재 (국문)**

> Flutter/Dart 기반 크로스플랫폼 모바일 앱으로 iOS와 Android를 동시에 지원한다.
> **최초 진입 시 카카오, 구글, 애플 계정을 이용한 간편 로그인을 제공하며,** 이후
> 보호자가 아기의 상태를 입력하는 화면, 판정 결과를 확인하는 화면, 마이크를 이용한
> 수면 환경 소음 측정, **FCM 푸시 알림 수신을** 담당한다. 단순 기록의 저장과 조회는
> Supabase 클라이언트를 통해 직접 처리된다.

**수정 (국문)**

> Flutter/Dart 기반 크로스플랫폼 모바일 앱으로 iOS와 Android를 동시에 지원한다.
> 이메일 로그인을 기본으로 하고 소셜 로그인 연동 구조를 함께 구현하였으며, 이후
> 보호자가 아기의 상태를 입력하는 화면, 판정 결과를 확인하는 화면, 마이크를 이용한
> 수면 환경 소음 측정, 수유 간격 알림을 담당한다. 단순 기록의 저장과 조회는 Supabase
> 클라이언트를 통해 직접 처리된다.

**현재 (영문)**

> A Flutter/Dart cross-platform mobile app supporting both iOS and Android. **It offers
> social sign-in with Kakao, Google, and Apple accounts,** and handles status input,
> result views, microphone-based noise measurement, and **FCM push notifications.**
> Simple record storage and retrieval are handled directly through the Supabase client.

**수정 (영문)**

> A Flutter/Dart cross-platform mobile app supporting both iOS and Android. It uses
> email sign-in by default, with social sign-in integrated at the client level, and
> handles status input, result views, microphone-based noise measurement, and local
> feeding-interval reminders. Simple record storage and retrieval are handled directly
> through the Supabase client.

*이유: 수유 알림은 기기 로컬 알림으로 실제 동작합니다. FCM 푸시는 미착수입니다.*

---

## 8. 3-4 (b) 애플리케이션 계층

**현재 (국문)**

> FastAPI 기반 통합 백엔드 서버로, Supabase Auth가 발급한 인증 토큰을 검증하여
> 요청자를 식별한다. **요청을 분석 계층으로 라우팅하기 전에 체온·수유량·수면·키·
> 몸무게 등 입력값의 범위를 검증하며,** 분석 결과를 앱이 사용할 형태로 조립하여
> 반환한다. 외부 AI API 호출을 이 계층에서만 수행하도록 제한한 것은…

**수정 (국문)**

> FastAPI 기반 백엔드 서버로, Supabase Auth가 발급한 인증 토큰을 검증하여 요청자를
> 식별하고 기능별 호출 상한을 적용한다. 이 계층은 외부 AI를 호출하는 요청, 즉 피부
> 이미지 해석과 상담 가이드 생성만을 담당하며, 요청을 분석 계층으로 넘기기 전에
> 이미지 형식·크기와 월령 등 입력값의 범위를 검증하고 분석 결과를 앱이 사용할
> 형태로 조립하여 반환한다. 체온·수유량·수면·키·몸무게 등 기록 입력값의 범위 검증은
> 앱과 데이터베이스 제약 조건이 담당한다. 외부 AI API 호출을 이 계층에서만 수행하도록
> 제한한 것은…

**현재 (영문)**

> A FastAPI unified backend server that verifies the authentication token issued by
> Supabase Auth. **It validates the range of input values before routing requests to the
> analysis layer,** and assembles analysis results into the response format used by the
> app. External AI API calls are confined to this layer because…

**수정 (영문)**

> A FastAPI backend server that verifies the authentication token issued by Supabase
> Auth and applies per-feature rate limits. This layer handles only the requests that
> call external AI — skin image interpretation and guidance generation — validating
> image format, size, and age in months before routing them to the analysis layer, and
> assembling results into the response format used by the app. Range checks on record
> inputs such as temperature, feeding volume, sleep, height, and weight are enforced by
> the app and by database constraints. External AI API calls are confined to this layer
> because…

---

## 9. 3-4 (c) 분석 계층 · 3-5 기술 ← **가장 큰 수정**

### 9-1. 3-4 (c)

**현재 (국문)**

> FastAPI 중계 서버 위에서 세 개의 모듈이 동작한다. 규칙 기반 판정 엔진은 공인
> 지침에서 도출한 연령대별 임계값을 적용하여 정상·주의·상담 권장의 3단계로 분류하고,
> 외부 LLM API 연동 모듈은 그 판정 결과를 문장형 행동 가이드로 변환한다. **피부
> 이미지 분류 모델은 자체 학습한 10개 클래스 CNN 분류기로, 외부 API를 호출하지 않고
> 서버 내에서 직접 추론을 수행한다.**

**수정 (국문)**

> 규칙 기반 판정 엔진은 공인 지침에서 도출한 연령대별 임계값을 적용하여 정상·주의·
> 상담 권장의 3단계로 분류하며, 외부 호출 없이 앱 내에서 수행된다. 판정 근거가 공인
> 지침에 고정되어야 하므로 이 엔진은 의도적으로 외부 AI에 의존하지 않는다. FastAPI
> 서버 위에서는 두 개의 외부 LLM 연동 모듈이 동작한다. 상담 가이드 모듈은 판정 결과와
> 최근 기록을 맥락으로 받아 문장형 행동 가이드를 생성하고, 피부 이미지 해석 모듈은
> 보호자가 촬영한 사진을 같은 LLM의 비전 기능으로 해석한다. 두 모듈은 하나의 API
> 키를 공유하되 호출 상한은 기능별로 분리하여, 한쪽의 사용량이 다른 쪽을 중단시키지
> 않도록 하였다.

**현재 (영문)**

> Three modules operate on a FastAPI relay server. The rule-based judgment engine applies
> age-specific thresholds derived from authoritative guidelines to classify status into
> three levels. The external LLM API module converts the judgment into sentence-level
> action guides. **The skin image classifier is an in-house ten-class CNN model that
> performs inference on the server without calling any external API.**

**수정 (영문)**

> The rule-based judgment engine applies age-specific thresholds derived from
> authoritative guidelines to classify status into three levels; it runs on the device
> without any external call, since the basis of each judgment must remain fixed to
> published guidelines. Two external-LLM modules operate on the FastAPI server. The
> guidance module converts a judgment and recent records into sentence-level action
> guides, and the skin module interprets caregiver-submitted photographs using the vision
> capability of the same model. The two modules share a single API key but are given
> separate rate limits so that usage of one cannot exhaust the other.

### 9-2. 3-5 기술 (2·3문단 교체)

**현재 (2문단)**

> 피부 분석은 아토피성 피부염, 흑색종 등 10개 클래스로 구성된 공개 피부 이미지
> 데이터셋[32][33]을 학습시킨 자체 분류 모델로 수행하며, 텍스트 기반의 상태 해석과
> 행동 가이드 생성에는 외부 LLM API 연동 모듈을 활용한다. 푸시 알림은 Firebase Cloud
> Messaging을 이용한다.

**현재 (3문단)**

> 다만 현재 모델은 학습 분할과 평가 분할 사이의 중복 여부를 확인하지 못하였고 정상
> 피부에 대한 별도의 평가 데이터가 없어, 측정된 성능 수치를 실제 서비스 환경에 대한
> 일반화 근거로 해석하기 어렵다. 실제 영유아 피부 이미지를 확보한 재검증이 필요하다.

**수정 (2문단)**

> 피부 이미지 해석과 텍스트 기반의 상태 해석·행동 가이드 생성에는 모두 외부 LLM API를
> 활용한다. 초기 설계에서는 공개 피부 이미지 데이터셋[32][33]을 학습시킨 10개 클래스
> 자체 분류기를 두었으나, 병명과 확률을 산출하는 형태가 3-8절에서 규정한 책임 범위와
> 충돌하여 이를 폐기하고 관찰 서술형 산출로 전환하였다.

**수정 (3문단)**

> 폐기의 이유는 성능이 아니라 산출 형태에 있다. 병명과 확률을 제시하는 순간 그 결과는
> 진단으로 읽히며, 학습 데이터에 없는 질환은 구조적으로 오분류될 수밖에 없다. 현재
> 구조는 병명과 확률을 반환하지 않고, 사진에서 관찰되는 특징을 최대 세 문장으로 서술한
> 뒤 '주의'와 '상담 권장'의 2단계만 제시한다. 다른 지표와 달리 '정상' 단계를 두지 않은
> 것은 사진 한 장으로는 정상이라고 말할 근거를 확보할 수 없기 때문이며, 모델이 사진을
> 판독하지 못한 경우에도 정상이 아니라 판독 불가로 처리한다. 다만 외부 LLM의 피부
> 이미지 해석 정확도를 영유아를 대상으로 정량 평가한 근거는 아직 확보하지 못하였으며,
> 이는 향후 과제로 남는다.

*3-5 첫 문단(프론트엔드·Supabase·FastAPI 역할)과 마지막의 "푸시 알림은 FCM을
이용한다"는 문장은 아래 10번과 함께 처리하십시오.*

---

## 10. 3-4 (d) 데이터 · 인프라 계층

**현재 (국문)**

> Supabase가 데이터베이스, 인증, 파일 저장을 함께 담당한다. 기록과 분석 결과는
> Supabase의 PostgreSQL에 **14개 테이블로** 저장되고, **피부 이미지 파일은 Supabase
> Storage에 보관되며,** 카카오·구글·애플 소셜 로그인과 세션 관리는 Supabase Auth가
> 처리한다. **예방접종 일정과 이상 징후 알림은 Firebase Cloud Messaging(FCM)을 통해
> 전달된다.**

**수정 (국문)**

> Supabase가 데이터베이스, 인증, 파일 저장을 함께 담당한다. 기록과 분석 결과는
> Supabase의 PostgreSQL에 19개 테이블로 저장되며, 소셜 로그인 연동과 세션 관리는
> Supabase Auth가 처리한다. 피부 이미지는 해석에만 사용하고 서버나 저장소에 보관하지
> 않는다. 예방접종 일정과 이상 징후의 푸시 알림은 Firebase Cloud Messaging(FCM)을
> 통해 전달하도록 설계하였으며, 수유 간격 알림은 기기 로컬 알림으로 구현하였다.

**현재 (영문)**

> Supabase provides the database, authentication, and file storage together. Records and
> analysis results are stored in Supabase PostgreSQL across **fourteen tables, skin image
> files are kept in Supabase Storage,** and Kakao, Google, and Apple social sign-in and
> session management are handled by Supabase Auth. **Vaccination schedules and anomaly
> alerts are delivered through Firebase Cloud Messaging (FCM).**

**수정 (영문)**

> Supabase provides the database, authentication, and file storage together. Records and
> analysis results are stored in Supabase PostgreSQL across nineteen tables, and social
> sign-in and session management are handled by Supabase Auth. Skin images are used for
> interpretation only and are not retained on the server or in storage. Push notifications
> for vaccination schedules and anomaly alerts are designed to be delivered through
> Firebase Cloud Messaging (FCM), while feeding-interval reminders are implemented as
> on-device local notifications.

*이미지를 보관하지 않는 것은 개인정보 측면에서 유리한 사실이므로 3-8절 안전장치에
한 줄 더 쓰셔도 좋습니다. (이번 수정 범위 밖이라 문안은 넣지 않았습니다.)*

**3-5 마지막 문장도 함께**

> 현재: 푸시 알림은 Firebase Cloud Messaging을 이용한다.
> 수정: 푸시 알림은 Firebase Cloud Messaging을 이용하도록 설계하였다.

---

## 11. 3-7 화면 구성

**현재**

> 앱의 화면은 **카카오·구글·애플 간편 로그인을 이용한** 인증·온보딩 단계를 거쳐 홈
> 대시보드로 진입하고…

**수정**

> 앱의 화면은 인증·온보딩 단계를 거쳐 홈 대시보드로 진입하고…

*그림 12 설명의 "소셜 로그인과 아기 정보 등록이 이루어지고"도 "로그인과 아기 정보
등록이 이루어지고"로 바꾸시면 캡션과 화면이 어긋나지 않습니다.*

---

## 12. 3-8 안전장치 및 책임 범위 — 셋째

**현재**

> 셋째, **외부 AI API의 응답이 실패하거나 신뢰도가 기준에 미치지 못할 경우,** 판정
> 결과 대신 전문의 상담을 권장하는 문구를 출력한다.

**수정**

> 셋째, 외부 AI API 호출이 실패하면 판정 결과를 임의로 생성하지 않고 실패 사실을
> 그대로 알린다. 피부 해석에서 모델이 사진을 판독하지 못한 경우에도 정상으로 처리하지
> 않고 판독 불가임을 명시하며, 발열이 동반된 경우와 생후 3개월 미만의 발열에 대해서는
> 모델의 판단과 무관하게 서버 코드가 단계를 상담 권장으로 상향한다.

*이유: 확률을 반환하지 않으므로 '신뢰도 기준'이라는 장치가 존재하지 않습니다. 대신
단계를 내리지 않고 올리기만 하는 잠금 장치가 실제로 구현되어 있어, 그쪽이 더 강한
근거가 됩니다.*

---

## 대조에서 확인된 일치 항목

원고를 고칠 필요가 없는 곳입니다. 심사 대응 시 근거로 쓰실 수 있습니다.

- **표 3 연령대별 체온 기준** — `36.5~37.5℃` 정상, 상담 권장 `38.0 / 38.5 / 39.0℃`가
  구현과 정확히 일치합니다.
- **수면 환경 소음 30 / 50 dB(A)** — 일치합니다. 다만 마이크 보정값(−15 dB)이 실제
  소음계와 대조되지 않은 상태이므로, 절대 음압 수준으로 해석하는 데는 한계가 있습니다.
- **판정 시점의 입력값 스냅샷과 규칙 버전 저장** (3-6) — `rule_version` 필드로 실제
  구현되어 있습니다. 원본 기록을 수정해도 과거 판정이 보존됩니다.
- **전 테이블 행 수준 보안(RLS)** (3-6) — 적용되어 있습니다.
- **지표별 독립 판정, 최고 단계를 대표로 표시** (3-3) — 구현과 일치합니다.
- **울음소리 분석이 원고에 없는 것** — 해당 기능은 제거되었으므로 현 상태와 맞습니다.

## 이번 수정에 포함하지 않은 것

논지에 영향을 주지 않아 제외했으나, 알고 계시면 좋습니다.

- 앱에는 있으나 원고에 없는 기능 셋 — **커뮤니티 게시판**, **함께 키우기**(보호자 간
  기록 공유), **대화형 상담 챗봇**. 특히 챗봇은 원고가 "판정 결과를 문장으로 변환하는
  모듈"로만 설명하는데, 실제로는 최근 기록 전체를 맥락으로 받는 대화 화면입니다.
- 표 2의 BabySense 지표 열에 위 기능들이 반영되어 있지 않습니다.
