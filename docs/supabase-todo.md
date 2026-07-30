# Supabase 연동 남은 작업

1단계(앱 정리)에서 Spring 의존을 걷어내며 확인한, **Supabase로 옮겨야 하는 남은 작업** 목록입니다.
스키마는 [supabase/schema.sql](../supabase/schema.sql)에 이미 있고 테이블도 만들어져 있습니다. 부족한 것은 앱 쪽 배선입니다.

## 현재 상태

테이블 14개 중 앱이 실제로 읽고 쓰는 것은 **11개**입니다.

| 테이블 | 상태 | 담당 코드 |
|---|---|---|
| `babies` | 연동됨 | `lib/core/services/baby_service.dart` |
| `growth_records` | 연동됨 | `lib/features/detail/growth/growth_record_service.dart` |
| `sleep_records` | 연동됨 (소음 측정 시 생성 + 수동 입력) | `noise_tracker.dart`, `sleep_record_service.dart` |
| `sleep_noise_logs` | 연동됨 (30건 배치) | `lib/core/services/noise_tracker.dart` |
| `profiles` | 트리거가 자동 생성 (앱은 읽지 않음) | — |
| `feeding_records` | 연동됨 | `lib/features/detail/feeding_record_service.dart` |
| `diaper_records` | 연동됨 | `lib/features/detail/diaper_record_service.dart` |
| `temperature_records` | 연동됨 | `lib/features/detail/temperature_record_service.dart` |
| `temperature_symptoms` | 연동됨 | `lib/features/detail/temperature_record_service.dart` |
| `vaccines` | 연동됨 | `lib/features/detail/vaccination_service.dart` |
| `vaccination_records` | 연동됨 | `lib/features/detail/vaccination_service.dart` |
| `skin_analyses` | **미연동** (모델 자체가 없음) | — |
| `assessments` | **미연동** (판정 규칙 미정) | — |
| `device_tokens` | **미연동** (FCM 설정 자체가 없음) | — |

## 해야 할 일

### A. 기록 화면 5종 — 완료

- [x] **수유** → `feeding_records` (`FeedingType`, 모유(직수)는 `amount_ml`이 NULL)
- [x] **배변** → `diaper_records` (`DiaperType`/`StoolState`, 소변이면 `stool_state`가 NULL)
- [x] **수면** → `sleep_records` (`SleepType`으로 교체, 자정 넘김 보정)
- [x] **체온** → `temperature_records` + `temperature_symptoms` ('없음'은 저장하지 않음)
- [x] **예방접종** → `vaccines` 조회 + `vaccination_records` (표준 일정 30건 기반, 하드코딩 제거)

CHECK 제약 준수는 `test/features/detail/record_rows_test.dart`가 고정합니다.
행을 만드는 부분을 `buildRow`로 분리해 Supabase 없이 검증합니다.

### B. AI 분석 결과 저장

FastAPI는 추론만 하고 DB에 쓰지 않습니다. 결과 저장은 앱이 합니다(RLS가 그대로 적용되도록).

- [ ] 피부 분석 결과 → `skin_analyses` (`image_path`는 Storage 경로 `{user_id}/{baby_id}/{파일명}`)
- [ ] 이미지 원본을 Supabase Storage에 업로드하는 코드 (`skin-images` 버킷)

`disease_result`에는 **모델이 준 원본 라벨**을 넣습니다. 한글 변환은 앱에서 합니다
(모델을 교체해도 과거 이력이 깨지지 않게 하려는 것 — schema.sql 2.10절 주석 참고).

### C. 기록 조회 — 지금 가장 아쉬운 부분

**저장은 되지만 볼 수가 없습니다.** 수유·배변·수면·체온은 입력 화면만 있어서,
사용자 입장에서는 저장한 데이터가 사라진 것처럼 보입니다. 성장 기록에만 이력 목록이
있으니(`growth_record_page.dart`의 `_buildRecordTile`) 그 형태를 참고하면 됩니다.

- [ ] 수유·배변·수면·체온 기록의 이력 조회 (날짜별 목록 + 삭제)
- [ ] 체온 이력은 `temperature_symptoms`를 함께 읽어 증상을 보여줘야 합니다

### D. 화면에 실제 데이터 연결

- [ ] **홈 화면이 전부 하드코딩입니다** — `'아이이름'`, `'분유 · 160ml'`, `'36.5°C'`,
      `'오전 11:20 ~ 오후 01:00'`, `'baby(아이이름)is sleeping very well'`.
      A가 끝났으니 이제 채울 재료는 있습니다.
- [ ] **로그아웃이 빈 함수** — `lib/features/mypage/mypage_page.dart`의 `onTap: () {}`.
      `Supabase.instance.client.auth.signOut()` 호출이 필요합니다.
- [ ] 소음 리포트를 실제 `sleep_noise_logs` 데이터로 계산
      (`noise_result_page.dart`는 지금 최대 dB만 보고 규칙 기반 문구를 냅니다)
- [ ] `assessments`(정상/주의/상담 권장 3단계 판정) 활용. 판정 규칙과 임계값을 먼저
      정해야 합니다 — 코드보다 결정이 먼저 필요한 항목입니다.

### E. 인프라

- [ ] **Supabase 대시보드: Google·Kakao provider 활성화** — 코드는 준비됐지만 서버에서 꺼져 있습니다
      (`/auth/v1/settings`가 둘 다 `false`). Redirect URLs에 `babysense://login-callback` 등록도 필요합니다.
      절차는 [social-login-setup.md](social-login-setup.md).
- [ ] **애플 로그인** — 미구현. Apple Developer Program 가입 필요.
      iOS 앱스토어는 소셜 로그인이 있으면 Sign in with Apple을 요구합니다.
- [ ] **Firebase 설정 파일** — `android/app/google-services.json`,
      `ios/Runner/GoogleService-Info.plist` 둘 다 없어 FCM이 동작하지 않습니다.
      `device_tokens` 테이블과 예방접종 알림이 여기에 걸려 있습니다.

## 검증 상태

소음 저장(`sleep_records` / `sleep_noise_logs`)의 실기기 확인 진행 상황입니다.

- [x] 측정을 시작하면 `sleep_records`에 행이 하나 생기고 `sleep_type`이 고른 값(`night`/`nap`)과 맞는지
      → **확인됨.** 백그라운드 isolate에서 Supabase 초기화가 성공한다는 뜻이기도 합니다
      (실패하면 행 자체가 만들어지지 않습니다).
- [ ] 30건마다 `sleep_noise_logs`에 배치가 쌓이는지
- [ ] 전송이 실패했을 때 버퍼를 유지하고 다음 배치에서 재시도하는지
- [ ] 측정을 중지하면 `sleep_records.ended_at`이 채워지는지

개발 맥에는 Android SDK가 없고 백그라운드 서비스가 macOS·시뮬레이터에서 정상 동작하지
않으므로, 남은 항목도 실기기에서 확인해야 합니다.

### 기록 화면 5종

CHECK 제약을 지키는지는 테스트로 고정했지만(`record_rows_test.dart`), **실제 Supabase에
행이 들어가는 것은 확인하지 못했습니다.** 앱에서 입력하고 대시보드 Table Editor로
확인해야 합니다. 특히 아래 조합이 제약과 부딪히기 쉬운 지점입니다.

- [ ] 수유에서 **모유(직수)** → `amount_ml`이 `null`
- [ ] 배변에서 **소변** → `stool_state`가 `null`
- [ ] 체온에서 **'없음'** → `temperature_symptoms`에 행이 없음
- [ ] 수면에서 **밤잠 오후 8시 ~ 오전 6시** → `ended_at`이 다음 날
- [ ] 예방접종 항목을 눌러 완료/취소 토글이 `vaccination_records`에 반영

모든 화면이 아이 등록을 전제로 합니다. 아이가 없으면
"먼저 아이 정보를 등록해주세요"가 뜹니다.
