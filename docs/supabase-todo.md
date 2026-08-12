# Supabase 연동 남은 작업

Spring 의존을 걷어내며 확인한, **Supabase로 옮겨야 하는 남은 작업** 목록입니다.
스키마는 [supabase/schema.sql](../supabase/schema.sql)에 있고, 이후 변경은
[supabase/migrations/](../supabase/migrations/)에 쌓습니다.

## 마이그레이션 적용 현황

007까지 **모두 운영 DB에 들어가 있습니다.**

| | 적용일 | 내용 |
|---|---|---|
| 001–003 | — | 판정 · cry_analyses 제거 · 커뮤니티 |
| 004 | 2026-08-11 | 함께 키우기(`owns_baby`) |
| 005 | 2026-08-12 | 아이 등록 실패(`insert ... returning`) 수정 |
| 006 | 2026-08-12 | 약 복용 · 병원 방문 표 |
| 007 | 2026-08-12 | 커뮤니티 글 갈래(`posts.category`) |

006·007은 적용 뒤 운영 DB에 실제 계정 두 개로 왕복시켜 확인했습니다.

- 투약·병원 방문 저장/조회, 잘못된 `reason` 거부(400)
- **RLS** — 다른 사용자에게 0건, 다른 사용자의 저장 거부(403)
- 갈래 붙여 글 작성, 갈래 없이 쓰면 `etc`, 갈래로 거르기, 없는 갈래 거부(400)
- 아이를 지우면 기록이 함께 사라지는지(FK cascade)

## 지금 당장 해야 할 것

**계정 두 개로 함께 키우기 흐름을 확인하세요.**

004는 2026-08-11 운영 DB에 적용됐습니다. 코드와 DB가 모두 준비됐지만 실제
초대 발급 → 입력 → 기록 공유는 해보지 못했습니다.

특히 **아이는 보이는데 기록이 안 보이면** `owns_baby()` 교체가 제대로 되지 않은
것입니다. 이 함수 하나가 기록 테이블 정책 16개의 판정 근거이기 때문입니다.

## 현재 상태

테이블 **20개** 중 앱이 실제로 읽고 쓰는 것은 **16개**입니다.
앱이 건드리지 않는 것은 `profiles`(트리거가 채움), `baby_invites`(RPC 경유),
`skin_analyses`·`device_tokens`(각각 모델·FCM 미비) 4개입니다.

| 테이블 | 상태 | 담당 코드 |
|---|---|---|
| `babies` | 연동됨 | `lib/core/services/baby_service.dart` |
| `baby_members` | 연동됨 | `lib/features/mypage/baby_member_service.dart` |
| `baby_invites` | 연동됨 | `lib/features/mypage/baby_member_service.dart` |
| `growth_records` | 연동됨 | `lib/features/detail/growth/growth_record_service.dart` |
| `sleep_records` | 연동됨 (소음 측정 시 생성 + 수동 입력) | `noise_tracker.dart`, `sleep_record_service.dart` |
| `sleep_noise_logs` | 연동됨 (30건 배치) | `lib/core/services/noise_tracker.dart` |
| `profiles` | 트리거가 자동 생성 (앱은 `list_baby_members`로 간접 조회) | — |
| `feeding_records` | 연동됨 | `lib/features/detail/feeding_record_service.dart` |
| `diaper_records` | 연동됨 | `lib/features/detail/diaper_record_service.dart` |
| `temperature_records` | 연동됨 | `lib/features/detail/temperature_record_service.dart` |
| `temperature_symptoms` | 연동됨 | `lib/features/detail/temperature_record_service.dart` |
| `vaccines` | 연동됨 | `lib/features/detail/vaccination_service.dart` |
| `vaccination_records` | 연동됨 | `lib/features/detail/vaccination_service.dart` |
| `assessments` | 연동됨 (저장: 체온 / 조회: 분석 탭) | `assessment_service.dart`, `analysis_page.dart` |
| `medication_records` | 연동됨 (006 적용 후) | `lib/features/detail/care/care_record_service.dart` |
| `hospital_visits` | 연동됨 (006 적용 후) | `lib/features/detail/care/care_record_service.dart` |
| `skin_analyses` | **미연동** (모델 자체가 없음) | — |
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

### B. AI 분석 결과 저장 — 모델 대기

> **선행 조건: 모델이 없습니다.** 피부 추론 모델이 없어 저장할 결과 자체가
> 없습니다. 이 항목은 모델이 준비된 뒤에 시작합니다.

- [ ] 피부 분석 결과 → `skin_analyses` (`image_path`는 Storage 경로 `{user_id}/{baby_id}/{파일명}`)
- [ ] 이미지 원본을 Supabase Storage에 업로드하는 코드 (`skin-images` 버킷)

`disease_result`에는 **모델이 준 원본 라벨**을 넣습니다. 한글 변환은 앱에서 합니다
(모델을 교체해도 과거 이력이 깨지지 않게 하려는 것 — schema.sql 2.10절 주석 참고).

### C. 기록 조회 — 완료

- [x] 각 입력 화면 아래 최근 20건 목록과 삭제 (`lib/features/detail/widgets/record_history.dart`)
- [x] 체온 이력은 중첩 select로 `temperature_symptoms`를 함께 읽습니다
- [x] **기록 탭** — 네 종류를 시간순으로 합친 목록 (`lib/features/records/`)

### D. 화면에 실제 데이터 연결 — 대부분 완료

- [x] **홈 화면** — `TodaySummary`가 오늘의 마지막 기록을 읽습니다.
      기록이 없으면 지어내지 않고 '기록 없음'을 표시합니다.
- [x] **로그아웃** — 설정 화면 한 곳에서 `auth.signOut()` (확인 대화상자 포함)
- [x] **분석 탭** — 최근 7일 집계 + `assessments` 조회 (`lib/features/analysis/`)
- [ ] **소음 리포트를 판정 규칙에 연결** — `noise_rules.dart`(WHO 1999 기준)를 만들어
      뒀지만 `noise_result_page.dart`는 여전히 근거 없는 50/70dB를 씁니다.
      **선행 조건**: `-15dB` 마이크 보정이 검증되지 않아, 바꿔도 "정말 30dB인가"를
      알 수 없습니다. 실제 소음계와 대조가 먼저입니다.
- [ ] `assessments`의 나머지 영역(성장·수면·수유·배변) — 임계값 미정.
      출처와 검증 상태는 [assessment-rules.md](assessment-rules.md) 참고.

### E. 함께 키우기 — 적용 완료

[004_add_baby_sharing.sql](../supabase/migrations/004_add_baby_sharing.sql)

- [x] `baby_members` / `baby_invites` 테이블과 RLS 정책
- [x] 기존 아이를 소유자로 이관하는 backfill (없으면 만든 사람도 자기 아이를 못 봅니다)
- [x] `owns_baby()` 교체 — 이 함수 하나가 기록 테이블 정책 16개의 판정 근거입니다
- [x] 초대 발급·입력 UI (`lib/features/mypage/co_parenting_page.dart`)
- [x] 로컬 PostgreSQL에서 18개 시나리오 검증
- [x] **운영 Supabase에 004 적용** (2026-08-11). 테이블 2개와 함수 3종이 모두
      응답하고, 권한 차단(`create_baby_invite` 거부)과 정보 비노출
      (`list_baby_members`가 빈 배열)까지 확인했습니다.
- [ ] 계정 두 개로 발급 → 입력 → **기록 공유**까지 실제 확인

### F. 인프라

- [ ] **Supabase 대시보드: Google·Kakao provider 활성화** — 코드는 준비됐지만 서버에서 꺼져 있습니다
      (`/auth/v1/settings`가 둘 다 `false`). Redirect URLs에 `babysense://login-callback` 등록도 필요합니다.
      절차는 [social-login-setup.md](social-login-setup.md).
- [ ] **애플 로그인** — 미구현. Apple Developer Program 가입 필요.
      iOS 앱스토어는 소셜 로그인이 있으면 Sign in with Apple을 요구합니다.
- [ ] **Firebase 설정 파일** — `android/app/google-services.json`,
      `ios/Runner/GoogleService-Info.plist` 둘 다 없어 FCM이 동작하지 않습니다.
      실행하면 `🔴 Firebase 초기화 실패: [core/not-initialized]`가 찍힙니다(앱은 계속 동작).
      `device_tokens` 테이블과 예방접종 알림이 여기에 걸려 있습니다.

## 검증 상태

### 함께 키우기 (로컬 PostgreSQL, 004 마이그레이션)

운영 DB에 넣기 전에 로컬에 PostgreSQL 16을 띄우고 Supabase의 `auth` 스키마·`auth.uid()`·
역할을 흉내 내, **기존 데이터가 있는 상태**로 마이그레이션을 적용해 확인했습니다.

- [x] 기존 아이가 소유자로 이관됨 (backfill)
- [x] 소유자가 자기 아이·기록을 계속 봄 / 초대 전 타인은 0건
- [x] 소유자가 초대 코드 발급 / 구성원 아닌 사람은 차단
- [x] 초대받는 쪽이 `baby_invites`를 훑을 수 없음 (0건)
- [x] 코드 수락 후 아이와 **기록까지** 보임 (정책 16개가 함께 따라옴)
- [x] 코드 재사용·만료·존재하지 않는 코드 거부
- [x] 구성원이 쓴 기록이 소유자에게 보임
- [x] `baby_members`에 직접 insert 시도가 RLS로 차단됨
- [x] 소유자는 탈퇴 불가(주인 없는 아이 방지) / 구성원은 탈퇴 가능
- [x] 새 아이 생성 시 트리거가 소유자를 자동 등록
- [x] `schema.sql` 단독으로 새 DB에 적용 (테이블 **20개**, 공유 함수 6/6)

검증 중 `SET LOCAL`을 트랜잭션 밖에서 써서 역할이 적용되지 않아 거짓 통과가 나온 적이
있습니다. RLS를 확인할 때는 반드시 `BEGIN; SET LOCAL role ...; ... COMMIT;`으로 감싸야 합니다.

### 함께 키우기 (운영 Supabase, 2026-08-11)

004 적용 직후 anon 키로 확인한 것입니다.

- [x] `baby_members` / `baby_invites` 테이블 존재
- [x] `list_baby_members` / `create_baby_invite` / `accept_baby_invite` 응답
- [x] 남의 아이 id로 초대 발급 시도 → **거부** ("아이를 등록한 사람만 만들 수 있습니다")
- [x] `list_baby_members`가 오류 대신 **빈 배열** → 아이의 존재 여부가 드러나지 않음
- [ ] 계정 두 개로 발급 → 입력 → 기록 공유

RPC를 인자 없이(`{}`) 부르면 함수가 있어도 404가 납니다. PostgREST는 이름과
**인자 시그니처**를 함께 보기 때문입니다. 적용 여부를 확인할 때는 실제 인자를
넣어야 합니다.

### 소음 저장 (실기기)

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

## 정리해야 할 테스트 데이터

로컬이 아니라 **운영 Supabase에 남아 있는 것들**입니다.

- 아이 `검증아기` (`edde3912-…`) 및 그에 딸린 기록 4건
- 계정 `community-check@babysense.dev`, `community-other@babysense.dev`
- 확인용으로 만든 계정들. 아이와 기록은 지웠지만 **계정 자체는 남아 있습니다** —
  `auth.users` 삭제는 `service_role` 키가 있어야 하는데, 그 키는 RLS를
  우회하므로 쓰지 않았습니다. Supabase 대시보드 Authentication에서 지우세요.
  - `migration-005-check-*`, `tz-check-*`, `tz-fixed-*`, `upsert-*`, `upsert2-*`
  - `advice-auth-check-*` (2026-08-12, /api/advice 인증 확인)
  - `mig-check-a-*`, `mig-check-b-*` (2026-08-12, 006·007 왕복 확인)
