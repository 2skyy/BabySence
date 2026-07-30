# Supabase 연동 남은 작업

1단계(앱 정리)에서 Spring 의존을 걷어내며 확인한, **Supabase로 옮겨야 하는 남은 작업** 목록입니다.
스키마는 [supabase/schema.sql](../supabase/schema.sql)에 이미 있고 테이블도 만들어져 있습니다. 부족한 것은 앱 쪽 배선입니다.

## 현재 상태

테이블 14개 중 앱이 실제로 읽고 쓰는 것은 **4개**입니다.

| 테이블 | 상태 | 담당 코드 |
|---|---|---|
| `babies` | 연동됨 | `lib/core/services/baby_service.dart` |
| `growth_records` | 연동됨 | `lib/features/detail/growth/growth_record_service.dart` |
| `sleep_records` | 연동됨 (소음 측정 시 생성) | `lib/core/services/noise_tracker.dart` |
| `sleep_noise_logs` | 연동됨 (30건 배치) | `lib/core/services/noise_tracker.dart` |
| `profiles` | 트리거가 자동 생성 (앱은 읽지 않음) | — |
| `feeding_records` | **미연동** | — |
| `diaper_records` | **미연동** | — |
| `temperature_records` | **미연동** | — |
| `temperature_symptoms` | **미연동** | — |
| `vaccines` | **미연동** (참조 데이터 시딩도 필요) | — |
| `vaccination_records` | **미연동** | — |
| `skin_analyses` | **미연동** | — |
| `device_tokens` | **미연동** (FCM 설정 자체가 없음) | — |

## 해야 할 일

### A. 기록 화면 5종 — 저장 코드가 아예 없습니다

화면 UI는 완성되어 있고 `setState`만 합니다. `growth_record_service.dart`를 본보기로 삼으면 화면당 30~50줄입니다.

- [ ] **수유** `lib/features/detail/feeding_record_page.dart` → `feeding_records`
      `feeding_type`은 `formula`/`breast`/`solid`. 모유(직수)는 `amount_ml`이 NULL이어야 합니다.
- [ ] **배변** `lib/features/detail/diaper_record_page.dart` → `diaper_records`
      `diaper_type`이 `urine`이면 `stool_state`는 반드시 NULL (CHECK 제약).
- [ ] **수면** `lib/features/detail/sleep_record_page.dart` → `sleep_records`
      ⚠️ 지금 `selectedSleepType`을 `'밤잠'`/`'낮잠'` **한글 문자열**로 들고 있습니다.
      `noise_tracker.dart`의 `SleepType` enum(`night`/`nap`)을 쓰도록 바꿔야 합니다.
      한글을 그대로 넣으면 CHECK 제약에 걸려 insert가 실패합니다.
- [ ] **체온** `lib/features/detail/temperature_record_page.dart` → `temperature_records` + `temperature_symptoms`
      증상은 별도 테이블에 다중 행. UI의 '없음'은 저장하지 않습니다(행이 없는 상태가 곧 '없음').
- [ ] **예방접종** `lib/features/detail/vaccination_page.dart` → `vaccines` 조회 + `vaccination_records`
      현재 `StatelessWidget`에 접종 일정이 하드코딩되어 있습니다.
      `vaccines`는 모든 사용자가 공유하는 참조 데이터라 **시딩이 먼저** 필요합니다.

### B. AI 분석 결과 저장

FastAPI는 추론만 하고 DB에 쓰지 않습니다. 결과 저장은 앱이 합니다(RLS가 그대로 적용되도록).

- [ ] 피부 분석 결과 → `skin_analyses` (`image_path`는 Storage 경로 `{user_id}/{baby_id}/{파일명}`)
- [ ] 이미지 원본을 Supabase Storage에 업로드하는 코드 (`skin-images` 버킷)

`disease_result`에는 **모델이 준 원본 라벨**을 넣습니다. 한글 변환은 앱에서 합니다
(모델을 교체해도 과거 이력이 깨지지 않게 하려는 것 — schema.sql 2.10절 주석 참고).

### C. 화면에 실제 데이터 연결

- [ ] **홈 화면이 전부 하드코딩입니다** — `'아이이름'`, `'분유 · 160ml'`, `'36.5°C'`,
      `'오전 11:20 ~ 오후 01:00'`, `'baby(아이이름)is sleeping very well'`.
      A가 끝나야 채울 수 있습니다.
- [ ] **로그아웃이 빈 함수** — `lib/features/mypage/mypage_page.dart`의 `onTap: () {}`.
      `Supabase.instance.client.auth.signOut()` 호출이 필요합니다.
- [ ] 소음 리포트를 실제 `sleep_noise_logs` 데이터로 계산
      (`noise_result_page.dart`는 지금 최대 dB만 보고 규칙 기반 문구를 냅니다)

### D. 인프라

- [ ] **Supabase 대시보드: Google·Kakao provider 활성화** — 코드는 준비됐지만 서버에서 꺼져 있습니다
      (`/auth/v1/settings`가 둘 다 `false`). Redirect URLs에 `babysense://login-callback` 등록도 필요합니다.
      절차는 [social-login-setup.md](social-login-setup.md).
- [ ] **애플 로그인** — 미구현. Apple Developer Program 가입 필요.
      iOS 앱스토어는 소셜 로그인이 있으면 Sign in with Apple을 요구합니다.
- [ ] **Firebase 설정 파일** — `android/app/google-services.json`,
      `ios/Runner/GoogleService-Info.plist` 둘 다 없어 FCM이 동작하지 않습니다.
      `device_tokens` 테이블과 예방접종 알림이 여기에 걸려 있습니다.

## 검증되지 않은 것

소음 저장(`sleep_records` / `sleep_noise_logs`)은 코드를 넣었지만 **실기기에서 확인하지 못했습니다.**
개발 맥에 Android SDK가 없고, 백그라운드 서비스가 macOS에서 동작하지 않기 때문입니다.
안드로이드 기기나 iOS 시뮬레이터에서 다음을 확인해야 합니다.

- 측정을 시작하면 `sleep_records`에 행이 하나 생기고 `sleep_type`이 고른 값(night/nap)과 맞는지
- 30건마다 `sleep_noise_logs`에 배치가 쌓이는지
- 측정을 중지하면 `ended_at`이 채워지는지
- 백그라운드 isolate에서 Supabase 초기화가 성공하는지 (로그: `백그라운드 Supabase 초기화 실패`가 없어야 함)
