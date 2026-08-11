# BabySense

육아 기록/모니터링 Flutter 앱. 로그인·회원가입, 아이 정보 온보딩, 홈 대시보드, 수유/체온/배변/수면/성장 기록, 예방접종, 커뮤니티, 함께 키우기(공동 육아)로 구성됩니다. 다른 육아 앱 대비 차별점으로 **피부 AI 분석**을 계획하고 있으나 **모델이 아직 없습니다**.

하단 탭 5개: **홈 · 기록 · 분석 · 커뮤니티 · 전체**

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

**3. Supabase 스키마**

- **DB를 새로 만드는 사람**: [`supabase/schema.sql`](supabase/schema.sql) 전체를
  Supabase 대시보드의 SQL Editor에 붙여넣고 실행합니다.
- **이미 쓰던 DB가 있는 사람**: [`supabase/migrations/`](supabase/migrations/)의
  파일을 번호 순으로 실행합니다. 여러 번 실행해도 안전합니다.

> ⚠️ **004(함께 키우기)가 아직 운영 DB에 적용되지 않았습니다.**
> 적용 전까지 마이페이지 → 함께 키우기 화면이 동작하지 않습니다.

테이블 설계는 [`docs/erd.md`](docs/erd.md) 참고.

소셜 로그인 설정은 [`docs/social-login-setup.md`](docs/social-login-setup.md)에 있습니다.

## 백엔드 구성

```
Flutter
 ├─> Supabase        Auth(인증) · PostgreSQL(모든 기록) · Storage(피부 사진)
 ├─> FastAPI (:8000) 육아 질문 답변 · 피부 AI 추론  ← 저장소의 server/
 │     └─> Claude API
 └─> Firebase        FCM 푸시 알림 (예정)
```

MySQL과 Spring 서버는 사용하지 않습니다. **FastAPI 서버는 DB에 붙지 않습니다.**
인증·기록 CRUD·Storage는 앱이 Supabase와 직접 처리하고, 분석 결과를 저장하는 것도
앱이 하므로 서버가 사용자 JWT를 중계할 필요가 없고 RLS가 그대로 적용됩니다.
서버 실행 방법은 [`server/README.md`](server/README.md)를 참고하세요.

**규칙 기반 판정은 앱에서 계산합니다.** 네트워크 없이도 즉시 안내를 띄우기 위해서이고,
판단 근거의 추적 가능성은 판정 시점의 입력값 스냅샷과 규칙 버전(`rule_version`)을 함께
저장해 확보합니다. 서버는 **외부 AI 호출과 피부 추론에만** 씁니다 — API 키가 앱에
포함되면 역컴파일로 탈취될 수 있기 때문입니다.

| 엔드포인트 | 상태 |
|---|---|
| `POST /api/advice` | ✅ `ANTHROPIC_API_KEY`가 있으면 동작 |
| `POST /api/skin/diagnose` | ❌ 모델 없음 → 503 |

인증·기록·판정은 **서버 없이도 전부 동작합니다.**

### 서버가 필요한 경우

**육아 질문 답변**이나 피부 분석을 쓸 때만 필요합니다. 터미널 두 개를 씁니다.

```bash
# 1) AI 서버
cd server && source venv/bin/activate
set -a; source .env; set +a          # ANTHROPIC_API_KEY를 읽습니다
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 2) 앱
flutter run --dart-define-from-file=env.json
```

> 🔑 **`server/.env`에 `ANTHROPIC_API_KEY`가 필요합니다.**
> 이 파일은 `.gitignore`로 막혀 있습니다. **앱(`env.json`)에는 넣지 마세요** —
> Flutter 패키지는 뜯어서 키를 꺼낼 수 있습니다.
>
> ```
> ANTHROPIC_API_KEY=sk-ant-...
> ```
>
> 키가 없어도 서버는 정상 기동하고 `/api/advice`만 503을 반환합니다.
> `/health`의 `advice.ready`로 확인할 수 있습니다.

실기기에서는 기본 주소(`10.0.2.2` / `127.0.0.1`)가 닿지 않으므로 개발 PC의 LAN IP를
넘겨야 합니다: `--dart-define=API_BASE_URL=http://192.168.0.10:8000`

## 프로젝트 구조

```
lib/
  core/
    constants/   # AppColors, AppRadius, AppSpacing, AppTextStyles, ApiConfig,
                 # SupabaseConfig, WhoGrowthStandards
    services/    # BabyService, NoiseTracker, SleepType, GrowthCalculator
    theme/       # AppTheme
    widgets/     # CommonButton, CommonTextField, CommonAppBar
  features/      # 화면 단위 폴더
    auth/           # 로그인 · 회원가입 · auth_gate · post_auth_route(로그인 후 분기)
    onboarding/     # 아이 정보 최초 등록 (등록 폼은 이 화면 한 곳에만 존재)
    shell/          # MainShell(하단 탭 5개) · 전체 탭 · 스플래시 · 준비 중 안내
    home/           # 홈 탭 · TodaySummary(오늘의 마지막 기록)
    records/        # 기록 탭 — 네 종류를 시간순으로 합친 목록
    analysis/       # 분석 탭 — 최근 7일 집계 · assessments 조회
    advice/         # 육아 질문 — 서버를 거쳐 Claude에 물어봅니다
    detail/         # 기록 화면 + 화면별 *_service.dart (Supabase 접근)
    detail/growth/  # 성장 기록 모델 · GrowthRepository · 페이지
    detail/assessment/ # 판정 규칙(체온·성장·소음)과 assessments 저장·조회
    community/      # 게시글 · 댓글 (작성 · 수정 · 삭제)
    mypage/         # 내 정보 · 아이 · 함께 키우기(초대 코드)
    settings/       # 알림 · 화면 · 앱 정보 · 로그아웃
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
- 테스트는 대상 파일과 같은 경로·같은 이름에 둡니다
  (`lib/features/mypage/baby_member_service.dart` → `test/features/mypage/baby_member_service_test.dart`).
  여러 파일에 걸친 동작을 검사하는 테스트만 예외입니다

> **`features/detail/`은 이름이 낡았습니다.** `DetailPage`에서 따온 이름인데 그 화면을
> 지웠습니다. 지금은 기록·소음·AI·판정이 한 폴더에 섞여 있습니다. 이 폴더를 가리키는
> import가 74곳이라 팀원 작업과 충돌할 위험이 커서 미뤄 뒀습니다.

## 코딩 가이드라인

이 저장소는 [`CLAUDE.md`](CLAUDE.md)의 원칙(가정하지 않고 확인하기, 최소한의 변경, 외과적 수정, 검증 가능한 목표)을 따릅니다.

## 최근 변경 사항

### 판정 3개 영역 · Claude 답변 · 상시 고지 (이번 작업)

논문(JDCS 투고본)과 코드를 대조해 어긋난 부분을 맞추고, 판정 영역을 **체온 하나에서
체온·성장·소음 셋으로** 늘렸습니다.

**성장 판정** ([growth_rules.dart](lib/features/detail/assessment/growth_rules.dart))

출처는 WHO Child Growth Standards(2006)입니다. 질병관리청·대한소아과학회 성장도표가
3세 미만 구간에 WHO 기준을 그대로 적용하므로 두 출처의 값이 같습니다.

- **Z-score −2 미만 주의, −3 미만 상담 권장**
- 경계는 **미만**입니다. 처음에 이하로 짰다가 테스트가 경계에서 걸려 출처를 다시
  확인했더니 WHO 정의가 "a Z-score **less than** −2"였습니다. 정확히 −2.0은 정상입니다.
- 체중-연령과 신장-연령 각각의 Z를 내고 **더 높은 단계**를 그 기록의 판정으로 삼습니다.
  두 지표가 같은 표에서 나오므로 서로 다른 출처를 섞는 것이 아닙니다.
- ⚠️ **위쪽(+2/+3)은 출처가 없습니다.** WHO는 낮은 쪽만 정의하고 과체중은
  체중-신장/BMI로 보라고 하는데 이 앱은 그 지표를 계산하지 않습니다. 대칭으로 놓은
  프로젝트 결정이며 판정 근거에 `upper_bound_is_project_decision: true`로 남깁니다.

**소음 판정을 30/50으로** ([noise_rules.dart](lib/features/detail/assessment/noise_rules.dart))

30dB 미만 정상 / 30~50 주의 / 50 초과 **개선 권장**. 근거는 WHO 침실 30dB과
Hugh et al.(2014)의 신생아실 상한 50dB입니다. WHO의 순간 45dB을 경계로 쓰지 않은 것은
대상이 영유아이고 50dB이 **영유아가 자는 공간을 직접 겨냥한 값**이기 때문입니다.

소음에서만 `consult`를 **'개선 권장'**으로 부릅니다. 환경 문제인데 '상담 권장'은 소음
때문에 병원 가라는 말로 읽힙니다. DB 값은 그대로 `consult`라 CHECK 제약과 3단계 구조는
유지됩니다.

**`NoiseResultPage`와 `loadNoiseStats`가 아무 데서도 호출되지 않았습니다.** 소음을
측정해도 결과가 사용자에게 도달할 경로가 없었습니다. 측정 중지 → 통계 조회 → 판정 →
결과 화면으로 연결했고, 결과 화면은 근거 없는 50/70dB로 문구를 직접 만들던 것을
규칙 기반으로 다시 썼습니다.

**Claude 답변** ([server/app/advice.py](server/app/advice.py))

앱이 아니라 **서버에서** 부릅니다. 시스템 프롬프트로 역할을 좁게 묶었습니다.

| 금지 | 이유 |
|---|---|
| 진단명·약 안내 | 의료행위 |
| **앱이 낸 판정을 뒤집는 것** | 판정은 공인 지침에서 뽑은 임계값으로 계산한 것이라, 모델이 뒤집으면 근거를 추적할 수 없습니다 |

반대로 3개월 미만 발열·경련·탈수 징후는 **다른 조언보다 먼저** 진료를 권하도록
지시합니다. 고지 문구는 서버가 고정 문자열로 붙입니다 — 모델이 쓰게 두면 답변마다
문구가 달라집니다.

맥락(개월 수·판정·최근 기록)은 앱이 조립합니다. 서버는 DB에 붙지 않습니다.
**아이 이름은 넣지 않습니다.**

**상시 고지** ([medical_disclaimer.dart](lib/core/widgets/medical_disclaimer.dart))

의료기기가 아니라는 고지를 한 곳에서 관리하고 판정·AI 문장을 보여주는 모든 자리에
붙였습니다(체온·성장·피부·분석 탭·Claude 답변). 화면마다 표현이 갈리면 어느 것이
공식 안내인지 알 수 없게 됩니다.

소음 실시간 표시의 **"위험 (소음 차단 필요!!)"** 를 **"개선 권장 (소음을 줄여 주세요)"**
로 바꿨습니다. 논문 3-8절이 금지한 표현입니다.

**기록 시각 입력 통일**

수유·배변·체온이 화면을 열면 지금 시각으로 시작하고, '지금' 버튼과 직접 수정을 함께
제공합니다. 배변은 `08:40`이 하드코딩돼 있어 그대로 저장하면 실제와 다른 시각이
들어갔고, 수유·체온은 시간을 **아예 고칠 수 없어** 나중에 몰아서 기록할 수 없었습니다.

수면은 기본값을 그대로 뒀습니다. 취침·기상을 둘 다 지금으로 채우면 길이 0인 기록이
되고, 저장 로직이 하루를 더해 **24시간 수면**이 됩니다.

**판정하지 않기로 한 영역**

수면·수유·배변은 출처에 구간표가 없어 판정하지 않습니다. 논문이 인용하는 수면 출처는
SIDS 예방 안내이고, 수유의 "하루 8~12회"는 신생아 모유수유 하나뿐입니다. 근거 없이
임계값을 만들면 "이 값의 근거는?"에 답할 수 없습니다. 종합 판정(`overall`)도 구현
범위에서 제외했습니다 — enum과 DB CHECK 값은 남아 있지만 계산 코드는 없습니다.

**보안** — `.gitignore`가 `.env`를 전혀 거르지 않았습니다. API 키를 넣기 전에
막았습니다. 논문 원고(`*.docx`)도 저장소에 넣지 않습니다.

**테스트 206 → 239.** 성장 20건, 소음 17건. 임계값 경계를 **출처 문구 그대로**
고정했습니다. 서버는 키 없이 확인 가능한 부분(프롬프트 조립·입력 검증·오류 매핑) 20건.

### 파일 구조·이름 정리

동작은 그대로 두고 **이름과 위치만** 바로잡았습니다. `flutter analyze` 이슈 없음,
테스트 170건 전부 통과.

**저장소에 빈 템플릿 프로젝트가 통째로 들어와 있었습니다.**

`my_app/` — 2026-05-14 커밋 "프론트 기능"에 쓸려 들어온 `flutter create` 결과물입니다.
`title: 'Flutter Demo'`의 카운터 예제 그대로였고, 최초 커밋 이후 **한 번도 수정되지
않았습니다**(`lib/main.dart`의 md5가 최초 커밋과 동일). 우리 코드는 아무것도 참조하지
않았고, 유일한 언급이 `analysis_options.yaml`의 제외 규칙이었습니다 — 지우는 대신
가려 둔 셈입니다.

추적 파일 131개를 제거했습니다. 자기 몫의 `android/ios/macos/windows/linux/web`과
`pubspec.yaml`을 갖고 있어 IDE가 별도 프로젝트로 인식하던 것도 함께 사라집니다.
되돌리려면 `git checkout 1633ac2 -- my_app`.

**빌드 산출물이 git에 추적되고 있었습니다.**

`.gitignore`가 `/build/`로 되어 있어 **최상위만** 걸러졌습니다. 그래서
`android/build/reports/problems/problems-report.html`이 추적되어, 빌드할 때마다
`git status`가 더러워졌습니다. `build/`로 고치고 인덱스에서 제거했습니다.

**이름이 뜻과 어긋나던 것들**

| 전 | 후 | 이유 |
|---|---|---|
| `eusick_page.dart` | `baby_food_page.dart` | `eusick`은 '이유식'의 잘못된 로마자 표기라 영어로도 한국어로도 읽히지 않습니다 |
| `noise_tracker.dart`의 `SleepType` | `core/services/sleep_type.dart` | 이 파일을 import하는 9곳 중 **6곳이 `show SleepType`을 붙여** 소음 추적기는 필요 없다고 말하고 있었습니다 |
| `test/.../noise_tracker_test.dart` | `sleep_type_test.dart` | 내용이 전부 `SleepType` 테스트였습니다 |
| `auth/login/login_page.dart` | `auth/login_page.dart` | 파일 하나짜리 폴더. `auth_gate.dart`는 이미 평평하게 있어 일관성이 없었습니다 |
| `auth/signup/signup_page.dart` | `auth/signup_page.dart` | 〃 |

**테스트 위치를 대상 파일과 맞췄습니다** — `record_history_test`는 `widgets/`로,
`temperature_rules_test`는 `assessment/`로, `baby_member_test`는
`baby_member_service_test`로.

**홈에서 마지막 하드코딩을 걷어냈습니다.** 하단 카드 두 개(수면 품질 `94%`, 활동량
`낮음`)가 완전 고정값이었습니다. 활동량은 측정할 수단 자체가 없고 수면 품질도
`sleep_records`만으로는 낼 수 없어, 값을 채우는 대신 카드를 없앴습니다.

### 함께 키우기 · 기록/분석 탭 · 미완성 화면 정리

**함께 키우기** — 아이 하나를 부모 둘이 함께 봅니다.
([004_add_baby_sharing.sql](supabase/migrations/004_add_baby_sharing.sql))

핵심은 **`owns_baby()` 함수 하나만 바꾸면 기록 테이블 정책 18개가 전부 공유를 따른다**는
점입니다. 정책을 하나씩 고치면 빠뜨린 테이블이 생기고, 그게 곧 정보 유출입니다.

- `baby_members`(구성원) + `baby_invites`(초대 코드) 테이블
- **기존 아이를 소유자로 옮기는 backfill이 반드시 먼저입니다.** 없으면 마이그레이션
  직후 만든 사람조차 자기 아이를 못 봅니다.
- 초대는 8자리 코드를 불러주는 방식(상대 계정을 몰라도 됨). 혼동되는 `0/O/1/I` 제외,
  7일 만료, 한 번 쓰면 소멸.
- `baby_members`에는 **INSERT 정책이 없습니다.** `accept_baby_invite()`
  (SECURITY DEFINER)만이 구성원을 추가할 수 있어, 아무 아이에나 자신을 끼워 넣을 수 없습니다.
- 초대받는 쪽은 `baby_invites`를 읽을 권한이 없습니다. 코드 목록을 훑을 수 없습니다.
- 소유자는 탈퇴할 수 없습니다(주인 없는 아이가 남습니다).
- 앱 화면: [`co_parenting_page.dart`](lib/features/mypage/co_parenting_page.dart) —
  구성원 목록, 코드 발급/복사, 코드 입력, 내보내기/그만두기

운영 DB에 넣기 전 **로컬 PostgreSQL에 Supabase의 `auth` 스키마를 흉내 내 18개 시나리오를
검증**했습니다. 목록은 [`docs/supabase-todo.md`](docs/supabase-todo.md) 참고.

**기록 탭 · 분석 탭** — 둘 다 "준비 중" 안내만 띄우던 자리였습니다.

- **기록 탭**([`lib/features/records/`](lib/features/records/)) — 기록 바로가기 5종 +
  **수유·배변·수면·체온을 시간순으로 합친 목록**(날짜별 `오늘`/`어제` 머리글).
  종전에는 수유 화면에서 수유만 보여 밤사이 흐름을 이어서 볼 수 없었습니다.
  아직 끝나지 않은 수면도 목록에 남깁니다 — 빠지면 "지금 자는 중"을 알 수 없습니다.
- **분석 탭**([`lib/features/analysis/`](lib/features/analysis/)) — 최근 7일 집계와
  판정 이력. 체온 화면이 `assessments`에 **저장은 계속 하고 있었는데
  `loadRecent()`가 한 번도 호출되지 않던 상태**였습니다.
  수면 합계는 끝난 수면만 더하므로 `끝난 수면 N건 기준`을 함께 적어 실제보다 짧게 나올 수
  있음을 숨기지 않습니다.

**버튼은 있는데 아무 일도 안 하던 것들**

- 이유식 분석의 `handleAnalyze()`가 `debugPrint` 한 줄이었고, 화면에 `사진 선택 UI (기능
  없음)`이라고 적혀 있었습니다. **사진 선택(카메라/앨범)까지 실제로 동작**하게 하고,
  분석 버튼은 모델이 없다고 알립니다. `AI가 성분을 분석해줍니다`라는 문구도 사실에
  맞게 고쳤습니다.
- 죽은 코드 제거: `detail_page.dart`(`'Detail Page'` 스텁)와 `/detail` 라우트,
  등록도 사용도 되지 않던 라우트 상수 3개.

**테스트 170건 전부 통과** (145 → 170). 새 로직은 순수 함수로 분리해 자격 증명 없이
검증합니다 — `mergeRecentRecords`, `WeeklySummary.from`, 초대 코드 정규화.
페이지 자체도 Supabase 없이 띄워 **조회 실패를 안내로 바꾸는지, 글자 확대 시 넘치지
않는지**를 확인합니다.

### 기록 화면 5종 Supabase 연동

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

## 앞으로 해야 할 일

세부 목록은 [`docs/supabase-todo.md`](docs/supabase-todo.md)에 있습니다. 여기서는 순서와
이유만 적습니다.

### 1순위 — 바로 할 수 있고, 막고 있는 것

| 할 일 | 왜 지금인가 |
|---|---|
| **운영 Supabase에 004 실행** | 함께 키우기 코드는 다 됐는데 DB가 없어 동작하지 않습니다. 2026-08-06 확인 시 `list_baby_members`가 `PGRST202`(함수 없음) |
| **계정 두 개로 함께 키우기 확인** | 로컬에서만 검증했습니다. 실제 초대 발급 → 입력 흐름은 미확인 |
| **기록 5종 실제 저장 확인** | CHECK 제약은 테스트로 막았지만 실제 행이 들어가는 건 확인 못 했습니다. 모유(직수)/소변/'없음'/자정 넘김 4가지 조합 |
| **운영 DB의 테스트 데이터 정리** | 아이 `검증아기`와 기록 4건, `community-*@babysense.dev` 계정 2개 |

### 2순위 — 남이 해줘야 진행되는 것

| 할 일 | 막고 있는 것 |
|---|---|
| **Firebase 설정 파일** | 없어서 FCM 전체가 죽어 있습니다. 기록 알림 · 예방접종 알림 · `device_tokens` 테이블이 전부 여기 걸려 있습니다 |
| **Supabase Google·Kakao provider 켜기** | 코드는 준비됐는데 서버에서 꺼져 있어 소셜 로그인이 실패합니다 |
| **피부 AI 모델** | 없어서 `/api/skin/diagnose`가 503입니다. **현재 동작하는 추론 엔드포인트가 하나도 없습니다** |
| **이유식 성분 분석 모델** | 사진 선택까지만 동작합니다 |
| **Apple Developer Program** ($99/년) | 애플 로그인 미구현. iOS 앱스토어는 소셜 로그인이 있으면 Sign in with Apple을 요구합니다 |

### 3순위 — 근거가 정해져야 하는 것

- **마이크 보정 검증** — `NoiseTracker`의 `-15dB`는 근거 없는 경험값입니다.
  실제 소음계와 대조하기 전에는 30/50dB 기준 충족 여부로 해석할 수 없습니다.
  **논문에 소음 수치를 쓴다면 이게 선행 조건입니다.** 판정 근거에
  `mic_offset_calibrated: false`로 남겨 두었습니다.
- **수면·수유·배변 판정** — 출처에 연령별 구간표가 없어 판정하지 않습니다.
  넣으려면 구간이 명시된 별도 출처가 필요합니다.
- **성장 판정의 위쪽 경계** — WHO는 낮은 쪽만 정의합니다. 위쪽을 인용 가능한 값으로
  만들려면 체중-신장 또는 BMI 지표를 추가해야 합니다.

영역별 출처와 검증 상태는 [`docs/assessment-rules.md`](docs/assessment-rules.md)에
수치마다 적어 두었습니다.

### 논문과 코드가 어긋난 곳 (논문을 고쳐야 함)

투고본과 대조한 결과입니다. 코드가 아니라 **논문 쪽을 수정**하는 것이 맞다고 판단한
항목입니다.

| 논문 | 코드 |
|---|---|
| 3-4(c) "FastAPI 위에서 **규칙 기반 판정 엔진**" | 규칙 엔진은 **Dart(앱)** |
| 3-4(b) "FastAPI가 **Supabase Auth 토큰을 검증**" | 서버는 JWT를 다루지 않음 |
| 3-4(b) "**서버가** 입력값 범위를 검증" | DB CHECK + 앱 두 겹 |
| 3-4(d) "**14개** 테이블" | **16개** (함께 키우기로 2개 추가) |
| 3-3 "가장 높은 단계를 대표 판정으로" | 종합 판정 미구현 (제외하기로 함) |
| 초록 "체온·성장·**수면·수유** 임계값" | **체온·성장·소음** |

기능 목록(3-2절)에서 ② 수유 이상 판단, ④ 배변 판단, ⑤의 "발달 단계", ⑥ 약 복용·병원
기록, ⑦ 예방접종 "판단"은 구현되지 않았습니다.

### 의도적으로 비워둔 것 (버그가 아님)

육아 가이드 · 진료용 리포트 · 공지사항 · 1:1 문의 · 다크 모드. 전부 "준비 중" 안내가
뜹니다. 눌러도 반응이 없으면 고장으로 보이기 때문입니다.

## 검증 상태

**확인됨 (실기기)**

- 소음 측정을 시작하면 `sleep_records`에 행이 생기고, `sleep_type`이 화면에서 고른
  값(`night`/`nap`)과 일치합니다. 백그라운드 isolate의 Supabase 초기화가 동작한다는 뜻이기도 합니다.

**확인됨 (iOS 시뮬레이터, 2026-08-06)**

- iPhone 17 Pro에서 Xcode 빌드 성공(46.4s), 앱 실행.
- Supabase 연결 정상 — 세션이 복원되고 `babies` 조회가 성공해 온보딩 화면까지 진입.
- 마이크 권한 요청 시 강제 종료 없음(`Info.plist` 수정 확인).
- Firebase는 설정 파일이 없어 `🔴 Firebase 초기화 실패: [core/not-initialized]`가 찍히지만
  **앱은 계속 동작합니다.**

**확인됨 (로컬 PostgreSQL)**

- 004 마이그레이션 18개 시나리오. 목록은 [`docs/supabase-todo.md`](docs/supabase-todo.md).

**확인됨 (자동 테스트, 170건)**

- 기록 합치기·7일 집계·초대 코드 정규화 같은 순수 로직.
- 기록/분석 탭이 조회 실패를 안내로 바꾸는지, 글자를 1.3배로 키워도 넘치지 않는지.

**확인됨 (Claude API, 2026-08-11)**

- `POST /api/advice`가 실제 답변을 반환합니다. 세 영역(체온·수면·성장)으로 확인:
  앱이 낸 판정을 **뒤집지 않고** 그대로 따르며, 3개월 미만 발열에서는 다른 조언보다
  먼저 진료를 권하고, 맥락으로 넘긴 수치("하루 평균 9시간")를 근거로 답합니다.
  진단명과 약 안내는 나오지 않았습니다.

**아직 확인되지 않음**

- **소음 판정의 실제 흐름** — 측정 중지 → 통계 조회 → 결과 화면 경로를 새로 만들었지만
  실기기에서 확인하지 못했습니다. 백그라운드 isolate가 남은 로그를 저장하는 동안
  조회하면 표본이 모자랄 수 있어, 중지 후 2초를 기다린 뒤 조회합니다. 이 대기가
  충분한지는 실측이 필요합니다.
- **성장 판정 화면** — 규칙과 저장은 테스트로 고정했지만 실제 입력 → 판정 카드 표시는
  미확인입니다.
- 새 기록/분석 탭에 **실제 데이터가 든 화면** — 시뮬레이터 계정에 아이가 등록돼 있지
  않아 빈 상태만 봤습니다. macOS 접근성 권한이 없어 GUI 자동 조작이 막혀 있습니다.
- 함께 키우기 실제 흐름 (004 미적용).
- 30건마다 `sleep_noise_logs`에 배치가 쌓이는지, 전송 실패 후 재시도가 동작하는지.
- 측정을 중지하면 `sleep_records.ended_at`이 채워지는지.

## 플랫폼 차이

- iOS는 `BGAppRefreshTask` 기반이라 **연속 소음 측정이 불가능**합니다. Android는
  foreground service로 계속 측정할 수 있습니다. 두 플랫폼의 기능을 동일하게 문서화하면 안 됩니다.
