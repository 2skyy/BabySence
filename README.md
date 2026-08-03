# BabySense

육아 기록/모니터링 Flutter 앱. 로그인·회원가입, 아이 정보 온보딩, 홈 대시보드(소음·피부 분석), 수유/체온/배변/수면/성장 기록, 예방접종, 마이페이지/설정 기능으로 구성됩니다. 다른 육아 앱 대비 차별점은 **피부 AI 분석**이며, 성장 추이 시각화 등 나머지 기능은 하나씩 채워가는 중입니다.

## 시작하기

> ⚠️ **저장소를 처음 받았거나 pull 후 앱이 안 켜진다면 이 절차를 먼저 확인하세요.**
> Supabase 연결 정보를 소스에 넣지 않고 `env.json`에서 주입받는데, 이 파일은
> `.gitignore`에 있어 저장소에 포함되지 않습니다. 없으면 앱이 시작하자마자 멈춥니다.

**1. `env.json` 만들기**

`env.example.json`을 복사해 `env.json`으로 이름을 바꾸고 값을 채웁니다.
값은 팀 내부에서 따로 공유받으세요 (**저장소에 커밋하지 마세요**).

```json
{
  "SUPABASE_URL": "https://<프로젝트ID>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "<publishable key>"
}
```

**2. 실행할 때 `env.json`을 넘기기**

이 인자를 빠뜨리면 앱이 시작하자마자 멈춥니다.

| 환경 | 방법 |
|---|---|
| 터미널 | `flutter run --dart-define-from-file=env.json` |
| **VS Code** | 실행 구성에서 **BabySense (env.json)** 선택 (`.vscode/launch.json`에 포함) |
| **Android Studio** | 실행 구성에서 **main.dart (env.json)** 선택 (`.run/`에 포함) |

목록에 안 보이면 IDE를 다시 열거나 아래처럼 직접 설정하세요.

- VS Code: `.vscode/launch.json`의 `toolArgs`에 `--dart-define-from-file=env.json`
- Android Studio: Run/Debug Configurations → **Additional run args**에 같은 값

**3. Supabase 스키마 (DB를 새로 만드는 사람만)**

[`supabase/schema.sql`](supabase/schema.sql) 전체를 Supabase 대시보드의
SQL Editor에 붙여넣고 실행합니다. 테이블 설계는 [`docs/erd.md`](docs/erd.md) 참고.

소셜 로그인 설정은 [`docs/social-login-setup.md`](docs/social-login-setup.md)에 있습니다.

## 백엔드 구성

```
Flutter
 ├─> Supabase        Auth(인증) · PostgreSQL(모든 기록) · Storage(피부 사진)
 ├─> FastAPI (:8000) 피부 AI 추론  ← 저장소의 server/
 └─> Firebase        FCM 푸시 알림 (예정)
```

MySQL과 Spring 서버는 사용하지 않습니다. **FastAPI 서버는 DB에 붙지 않는 추론 전용**이며,
인증·기록 CRUD·Storage는 앱이 Supabase와 직접 처리합니다. 분석 결과를 저장하는 것도
앱이 하므로 서버가 사용자 JWT를 중계할 필요가 없고 RLS가 그대로 적용됩니다.
서버 실행 방법은 [`server/README.md`](server/README.md)를 참고하세요.

> 피부 모델이 아직 준비되지 않아 `/api/skin/diagnose`는 503을 반환합니다.
> 즉 **현재 동작하는 추론 엔드포인트가 없습니다.** 인증·기록 기능은 서버 없이 동작합니다.

### 서버가 필요한 경우

터미널 두 개가 필요합니다.

```bash
# 1) AI 서버 (피부 분석을 볼 때만)
cd server && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 2) 앱
flutter run --dart-define-from-file=env.json
```

실기기에서는 기본 주소(`10.0.2.2` / `127.0.0.1`)가 닿지 않으므로 개발 PC의 LAN IP를
넘겨야 합니다: `--dart-define=API_BASE_URL=http://192.168.0.10:8000`

## 프로젝트 구조

```
lib/
  core/
    constants/   # AppColors, AppRadius, AppSpacing, AppTextStyles, ApiConfig,
                 # SupabaseConfig, WhoGrowthStandards
    services/    # BabyService, NoiseTracker(+SleepType), GrowthCalculator
    theme/       # AppTheme
    widgets/     # CommonButton, CommonTextField, CommonAppBar
  features/      # 화면 단위 폴더 (auth, onboarding, detail, home, mypage, settings)
    auth/           # 로그인 · 회원가입 · post_auth_route(로그인 후 분기)
    onboarding/     # 아이 정보 최초 등록 (등록 폼은 이 화면 한 곳에만 존재)
    detail/         # 기록 화면 + 화면별 *_service.dart (Supabase 접근)
    detail/growth/  # 성장 기록 모델 · GrowthRepository · 페이지
  routes/        # AppRoutes (라우트 문자열 상수)
  main.dart      # 앱 진입점 + Supabase 초기화 + 백그라운드 소음 측정 서비스
server/          # FastAPI 추론 서버 (피부)
test/            # lib/ 구조를 1:1로 반영 (test/core/services, test/features/...)
docs/            # ERD, 소셜 로그인 설정, Supabase 남은 작업, 논문용 문서
supabase/        # schema.sql (테이블 · RLS · 마스터 데이터), migrations/
```

- 공통 스타일은 `core/constants`의 상수와 `core/widgets`의 공통 위젯으로 관리
- 네비게이션은 `AppRoutes` 상수 경유가 원칙 (일부 화면은 `MaterialPageRoute` 직접 사용도 혼재)
- 서버 주소는 `ApiConfig` 한 곳에서만 정의합니다. 화면에 URL을 하드코딩하지 마세요
- Supabase 접근은 화면에서 직접 호출하지 않고 `core/services` 또는 feature별 서비스를 경유합니다

## 코딩 가이드라인

이 저장소는 [`CLAUDE.md`](CLAUDE.md)의 원칙(가정하지 않고 확인하기, 최소한의 변경, 외과적 수정, 검증 가능한 목표)을 따릅니다.

## 최근 변경 사항

### 기록 화면 5종 Supabase 연동 (이번 작업)

수유·배변·수면·체온·예방접종 화면은 UI만 있고 저장 코드가 없어, 입력해도 화면을
나가면 사라졌습니다. 5종 모두 Supabase에 저장하도록 연결했습니다.
**앱이 사용하는 테이블이 4개 → 11개가 되었습니다.**

| 화면 | 테이블 | 서비스 |
|---|---|---|
| 수유 | `feeding_records` | `feeding_record_service.dart` |
| 배변 | `diaper_records` | `diaper_record_service.dart` |
| 수면 | `sleep_records` | `sleep_record_service.dart` |
| 체온 | `temperature_records` + `temperature_symptoms` | `temperature_record_service.dart` |
| 예방접종 | `vaccines` 조회 + `vaccination_records` | `vaccination_service.dart` |

**CHECK 제약을 enum으로 막았습니다.** 한글 문자열을 그대로 넣으면 insert가 실패하고,
앱에는 원인 없는 "저장하지 못했습니다"만 뜹니다. `SleepType`과 같은 방식으로
**enum 이름 = DB 값**으로 맞췄습니다.

- `FeedingType`(`formula`/`breast`/`solid`) — **모유(직수)는 `amount_ml`을 NULL로** 두고 입력 필드도 비활성화합니다(계량 불가)
- `DiaperType`(`urine`/`stool`/`mixed`) · `StoolState`(`golden`/`green`/`loose`/`hard`) — **소변이면 `stool_state`를 NULL로** (`diaper_stool_state_consistent`는 양방향 제약이라 그 외에는 반드시 값이 있어야 합니다)
- `Symptom` — `runnyNose` → `runny_nose` 변환. **UI의 '없음'은 저장하지 않습니다.** 행이 하나도 없는 상태가 곧 '없음'입니다
- 수면 화면이 들고 있던 `'밤잠'`/`'낮잠'` **한글 문자열을 `SleepType`으로 교체**했습니다

**시각 처리** — 배변·수면 화면은 오전/오후 + 시:분만 받고 날짜가 없습니다. 오늘 날짜로
만들되 미래가 되면 어제로 봅니다(아침에 전날 밤잠을 기록하는 것이 정상적인 사용).
수면은 기상이 취침보다 이르면 하루를 더합니다(`sleep_period_valid` 제약). 취침과
기상이 같은 시각인 경우도 마찬가지입니다.

**예방접종 화면을 다시 썼습니다.** `StatelessWidget`에 BCG/DTaP 등이 하드코딩되어
있었는데, 스키마에 이미 시딩된 **표준 일정 30건**을 읽어오도록 바꿨습니다. 디자인은
유지했고, 예정일은 `생년월일 + 권장 개월 수`로 계산하며 항목을 누르면 접종 완료/취소가
토글됩니다. 예정일이 지난 항목은 따로 표시합니다.

`addMonths`를 직접 구현한 이유가 있습니다 — Dart의 `DateTime(2026, 2, 31)`은 3월 3일로
넘어가버립니다. 1월 31일생 아이의 1개월 예정일이 3월로 밀리는 버그가 생기므로 그 달의
마지막 날로 맞췄습니다.

**테스트 23건 추가** (15 → 38). Supabase 자격증명 없이 검증할 수 있도록, 행을 만드는
부분을 `buildRow`로 분리해 전송과 나눴습니다.

- `record_enums_test.dart` — enum 이름이 CHECK 값과 일치하는지, `addMonths` 경계
- `record_rows_test.dart` — 실제 전송되는 행. 위에 적은 네 가지 함정과 **그 반대쪽**까지 검사합니다(한쪽만 맞으면 제약을 절반만 지키는 셈이라서)

### Spring 의존 제거 · 플랫폼 설정 · FastAPI 서버

방향을 **Supabase(DB·인증) + FastAPI(AI 추론), Android·iOS 동시 지원**으로 확정하고,
앱에서 Spring/MySQL 흔적을 걷어낸 뒤 서버를 저장소 안에 새로 두었습니다.

**iOS 네이티브 설정** — Android만 설정되어 있어 두 가지가 실제로 터지고 있었습니다.

- `Info.plist`에 `CFBundleURLTypes`(`babysense`)가 없어 소셜 로그인이 iOS에서 앱으로 복귀하지 못했습니다.
- `NSMicrophoneUsageDescription`이 없어 iOS에서 마이크 권한을 요청하는 순간 OS가 프로세스를 죽였습니다. 예외 처리로 잡히지 않습니다. 카메라·사진 권한 설명도 함께 넣었습니다(`image_picker` 사용).
- `UIBackgroundModes`(audio/fetch/processing)와 `BGTaskSchedulerPermittedIdentifiers` 추가.
- 배포 타깃 13.0 → **15.0**. `firebase_core`/`firebase_messaging`의 podspec 요구사항이며, 13.0이면 `pod install`이 실패합니다.
- Android에는 `url_launcher`가 브라우저를 찾도록 `<queries>`를 추가했습니다. Android 11부터 이 선언 없이는 브라우저를 열 수 없습니다.

**Spring 의존 제거**

- 온보딩(`child_info_page`)을 HTTP 호출에서 `BabyService.create()`로 재배선. `int userId`(uuid와 불일치), 성별 `'MALE'/'FEMALE'`(CHECK는 소문자), `weight`(`babies`에 없는 컬럼) 전제를 정리했습니다. 몸무게는 버리지 않고 오늘 날짜의 `growth_records` 한 건으로 저장합니다.
- 어디서도 참조되지 않던 `SessionManager` 삭제(Supabase가 세션 관리).
- 온보딩이 고아 상태였던 문제를 `post_auth_route`로 해결. 로그인·회원가입 성공 시 아이가 없으면 온보딩, 있으면 홈으로 보냅니다.
- 하드코딩된 서버 주소 4곳을 `ApiConfig` 한 곳으로 모았습니다.
- 아이 등록 폼이 온보딩과 성장 기록 화면에 중복되어 있어 **온보딩 한 곳만** 남겼습니다.

**소음 측정 데이터가 틀렸던 문제** — 논문에 이 데이터를 쓴다면 확인이 필요합니다.

- `main.dart`에서 `-15dB` + EMA(85:15)를 적용한 값을 `NoiseTracker`가 다시 `-8dB` + EMA(70:30)로 처리해 **총 -23dB에 이중 평활**이 걸려 있었습니다. 보정을 한 곳으로 모으고 UI 표시값과 저장값을 같게 했습니다.
- 30dB 미만이면 실측값을 버리고 `30.0 + (adjustedDb % 2.0)`으로 **값을 지어내던** 코드를 제거했습니다. 조용한 방에서는 항상 이 분기를 타므로 저장된 야간 데이터 상당수가 측정값이 아니었습니다.
- 전송 **전에** 버퍼를 비워 실패 시 30건이 유실됐습니다. 성공 후에만 비우고 재시도합니다.
- `recordId = 1` 하드코딩을 제거하고, 측정 시작 시 `sleep_records` 행을 만들어 그 uuid를 씁니다. 종료 시 `ended_at`을 채웁니다.
- **밤잠/낮잠 구분**을 위한 `SleepType` enum 추가. enum 이름이 곧 DB CHECK 값(`night`/`nap`)입니다. 측정 중에는 선택이 잠깁니다.
- 백그라운드 서비스는 별도 isolate라 `main()`의 초기화가 닿지 않습니다. `onStart`에서 Supabase를 다시 초기화하지 않으면 소음 저장이 전부 실패합니다.

**그 외 수정**

- `statuses[Permission.microphone]!` 강제 언래핑 → 안전한 접근
- 로그인 화면의 뒤로가기 버튼 제거(`initialRoute`라 스택이 비어 검은 화면이 됐습니다)
- `flutter_local_notifications`의 `initialize()` 호출이 아예 없어 **iOS에서 알림이 전혀 뜨지 않았습니다**
- `analysis_options.yaml`에 `build/` 제외 추가 — 빌드 산출물에서 152개 오류가 나오고 있었습니다

**FastAPI 추론 서버** ([`server/`](server/))

- 역할을 좁게 잡았습니다. 추론만 하고 DB에 붙지 않습니다. 서버가 사용자 JWT를 중계할 필요가 없고 RLS가 그대로 적용됩니다.
- 폐기하는 Spring에서 이식한 것: 확률 50% 미만이면 진단명 대신 재촬영 안내(오진 방지, 앱도 `status`로 구분), 업로드 상한 50MB, 응답 계약 `{status, disease, probability}`.
- **피부 모델이 없어 현재 동작하는 추론 엔드포인트가 없습니다.** 이전 파이썬 서버는 항상 `Atopic Dermatitis 88.4%`를 돌려줬지만, 고정값을 진단처럼 보여주는 것은 사용자를 오도하므로 옮기지 않았습니다.

**울음소리 분석 제거** — 사용하지 않기로 결정. 앱 화면·홈 버튼·서버 모듈·`librosa`/`scikit-learn` 의존성·모델 파일·스키마·문서에서 모두 제거했습니다.

**테스트** — `lib/` 구조를 1:1로 반영하도록 재배치했습니다.

- `GrowthRepository`를 도입해 `GrowthRecordPage`가 Supabase에 직접 붙지 않게 했습니다. static 메서드 탓에 위젯 테스트가 불가능했습니다.
- 카운터를 검사하던 기본 템플릿 `widget_test.dart`와 사라진 폼을 검사하던 구 테스트를 정리하고, 가짜 저장소 기반 위젯 테스트 6건 + `SleepType` 단위 테스트 4건을 추가했습니다. **총 15건 전부 통과.**

### Supabase 연동

- **DB 설계**: [`docs/erd.md`](docs/erd.md)에 ERD와 14개 테이블 명세서, [`supabase/schema.sql`](supabase/schema.sql)에 실행 가능한 DDL·RLS 정책·예방접종 마스터 데이터(0~24개월 30건) 추가. MySQL은 사용하지 않기로 결정
- **연결 정보 분리**: `main.dart`에 하드코딩돼 있던 Supabase URL/키를 `SupabaseConfig` + `env.json`(`--dart-define-from-file`)으로 이전. 연결 정보가 없으면 시작 시점에 안내와 함께 즉시 중단하도록 변경(초기화 실패를 삼킨 채 앱이 뜨면 나중에 원인 모를 에러가 나기 때문)
- **인증 교체**: 로그인/회원가입을 Spring `/api/users/*`에서 Supabase Auth(`signInWithPassword`, `signUp`)로 교체. 홈 이동 처리는 `onAuthStateChange` 리스너 한 곳으로 모음(소셜 로그인은 브라우저 복귀 후에야 완료되므로)
- **소셜 로그인**: 구글·카카오를 `signInWithOAuth` 웹 리디렉트 방식으로 추가(client ID를 앱에 넣지 않음). 딥링크 `babysense://login-callback` intent-filter 추가. 애플은 Apple Developer Program(연 $99) 필요로 보류 — 설정 절차는 [`docs/social-login-setup.md`](docs/social-login-setup.md) 참고
- **성장 기록 이전**: `SharedPreferences` 로컬 저장에서 Supabase `babies` / `growth_records` 테이블로 이전. `babies.name`이 필수라 아이 등록 화면에 이름 입력 추가. RLS가 소유권을 보장하므로 쿼리에 `user_id` 조건을 걸지 않음
- **회원가입 화면 오버플로 수정**: 키보드가 올라올 때 나던 노란 빗금(RenderFlex overflow) 해결 — 로그인 화면과 동일한 스크롤 레이아웃 적용

### 이전 작업

- **`build/` git 추적 해제**: `.gitignore`에는 등록돼 있었지만 과거에 커밋되어 계속 추적되던 빌드 산출물을 `git rm --cached`로 인덱스에서 제거
- **`AppColors.primary` 색상값 수정**: 미사용 값(`0xFF3B82F6`)이던 것을 로그인/회원가입/온보딩 화면에서 실제로 쓰이던 브랜드 컬러(`0xFF3182F6`, Toss Blue)로 통일
- **`login_page.dart` 리팩토링**: 인라인 하드코딩 색상을 `AppColors.primary`로, 로그인 버튼을 `CommonButton`으로 교체. `CommonButton`에는 기존 로그인 버튼에 있던 로딩 스피너 동작을 유지하기 위해 `isLoading` 옵션을 추가. 팀원이 `feature/auth-ui`에 푸시한 최신 로그인 화면(스크롤 레이아웃 수정, 로컬 API 주소)을 기준으로 다시 적용함
- **로깅/미사용 코드 정리**: `signup_page.dart`, `skin_analysis_page.dart`의 `print()`를 `debugPrint()`로 교체, `main.dart`의 미사용 `noiseSubscription` 변수 제거
- **`deprecated_member_use` 정리**: `settings_page.dart`, `mypage_page.dart`, `feeding_record_page.dart`, `sleep_record_page.dart`, `diaper_record_page.dart`에서 `withOpacity` → `withValues(alpha:)`로 교체
- **detail 화면 색상 통일**: `temperature_record_page.dart`의 로컬 중복 색상(`primaryColor`/`borderColor`/`secondaryTextColor`)을 값이 동일한 `AppColors.error`/`AppColors.border`/`AppColors.textSecondary`로 교체(시각적 변화 없음). `feeding_record_page.dart`, `sleep_record_page.dart`, `diaper_record_page.dart`, `eusick_page.dart`의 로컬 `primaryColor`(구 미사용 값과 동일한 `0xFF3B82F6`)를 `AppColors.primary`로 통일(4개 화면의 파란색이 브랜드 컬러로 변경됨)

이번 라운드에서는 `home_page.dart`, `skin_analysis_page.dart`의 색상, `signup_page.dart`의 색상은 다른 미완성 작업(WIP)과 겹쳐 있어 의도적으로 제외했습니다.

- **성장 추이 시각화 기능 추가**: 홈 화면 "성장" 타일에서 진입. 최초 진입 시 아이 성별·생년월일을 로컬에 저장하고, 이후 키/몸무게를 기록하면 WHO 성장 표준(2006, 0~24개월) 백분위 곡선(3rd/15th/50th/85th/97th)과 우리 아이 데이터를 겹쳐서 보여줌
  - `lib/core/constants/who_growth_standards.dart`: WHO 공식 저장소([WorldHealthOrganization/anthro](https://github.com/WorldHealthOrganization/anthro))에서 가져온 체중/신장 LMS 파라미터를 내장 (월별 체크포인트, 남/녀 각각)
  - `lib/core/services/growth_calculator.dart`: LMS(Box-Cox) 공식으로 백분위 ↔ 실측값을 변환. `test/growth_calculator_test.dart`에서 WHO 공식 수치와의 일치 여부를 검증
  - `lib/features/detail/growth/`: `GrowthRecord`/`GrowthProfile` 모델, `shared_preferences` 기반 로컬 저장 서비스(백엔드 API가 아직 없어 로컬에만 저장), `GrowthRecordPage`(입력 폼 + 이력 + `fl_chart` 라인 차트)
  - `pubspec.yaml`에 `fl_chart`, `shared_preferences` 의존성 추가

## 알려진 이슈

남은 작업 목록은 [`docs/supabase-todo.md`](docs/supabase-todo.md)에 정리되어 있습니다.

**미구현**

- 홈 화면의 값(`'아이이름'`, `'분유 · 160ml'`, `'36.5°C'` 등)이 전부 하드코딩입니다.
- `mypage_page.dart`의 Logout 메뉴가 `onTap: () {}` 상태입니다. `auth.signOut()` 연결이 필요합니다.
- 앱 재시작 시 저장된 세션을 확인하지 않고 항상 로그인 화면으로 진입합니다.
- `assessments` 테이블(정상/주의/상담 권장 3단계 판정)에 접근하는 코드가 아직 없습니다. 판정 규칙과 임계값을 먼저 정해야 합니다.
- 앱이 사용하는 테이블은 14개 중 **11개**입니다. 쓰지 않는 것은 `skin_analyses`(모델 자체가 없음), `device_tokens`(FCM 미설정), `profiles`(트리거가 자동 생성하며 앱은 읽지 않음)입니다.

**설정이 필요한 것**

- 피부 AI 모델이 없어 `POST /api/skin/diagnose`가 503을 반환합니다.
- Supabase 대시보드에서 Google·Kakao provider가 꺼져 있어 소셜 로그인이 실패합니다. Redirect URLs에 `babysense://login-callback` 등록도 필요합니다.
- 애플 로그인 미구현(Apple Developer Program 필요). iOS 앱스토어는 소셜 로그인이 있으면 Sign in with Apple을 요구합니다.
- Firebase 설정 파일(`google-services.json`, `GoogleService-Info.plist`)이 없어 FCM이 동작하지 않습니다.

**검증 상태**

확인됨 (실기기)

- 소음 측정을 시작하면 `sleep_records`에 행이 생기고, `sleep_type`이 화면에서 고른 값(`night`/`nap`)과 일치합니다. 백그라운드 isolate의 Supabase 초기화가 동작한다는 뜻이기도 합니다.

확인됨 (iOS 시뮬레이터)

- 앱 실행, Supabase 초기화, 마이크 권한 요청 시 강제 종료 없음(`Info.plist` 수정 확인), 로그인 화면 렌더링.

아직 확인되지 않음

- 30건마다 `sleep_noise_logs`에 배치가 쌓이는지, 전송 실패 후 재시도가 동작하는지.
- 측정을 중지하면 `sleep_records.ended_at`이 채워지는지.
- 로그인 이후 흐름(온보딩 → `babies` 저장 → 성장 기록).
- `NoiseTracker`의 `-15dB` 보정값은 근거가 없는 경험값입니다. 논문에 소음 수치를 쓴다면 실제 소음계와 대조해 정해야 합니다.

**플랫폼 차이**

- iOS는 `BGAppRefreshTask` 기반이라 **연속 소음 측정이 불가능**합니다. Android는 foreground service로 계속 측정할 수 있습니다. 두 플랫폼의 기능을 동일하게 문서화하면 안 됩니다.
