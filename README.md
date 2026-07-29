# BabySense

육아 기록/모니터링 Flutter 앱. 로그인·회원가입, 아이 정보 온보딩, 홈 대시보드(소음·피부·울음 분석), 수유/체온/배변/수면/성장 기록, 예방접종, 마이페이지/설정 기능으로 구성됩니다. 다른 육아 앱 대비 차별점은 **피부 AI 분석**이며, 성장 추이 시각화 등 나머지 기능은 하나씩 채워가는 중입니다.

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
 ├─> Supabase       Auth(인증) · PostgreSQL(모든 기록) · Storage(사진/오디오)
 ├─> Spring (:8080) 피부·울음 AI 중계 ──> Python (:8000, :5001)
 └─> Firebase       FCM 푸시 알림 (예정)
```

MySQL은 사용하지 않습니다. Spring 서버는 파이썬 AI 서버로 요청을 넘기는 중계 역할이며,
분석 결과 저장은 Flutter가 Supabase에 직접 수행합니다.

## 프로젝트 구조

```
lib/
  core/
    constants/   # AppColors, AppRadius, AppSpacing, AppTextStyles, SupabaseConfig, WhoGrowthStandards
    services/    # BabyService, NoiseTracker, GrowthCalculator
    theme/       # AppTheme
    widgets/     # CommonButton, CommonTextField, CommonAppBar
  features/      # 화면 단위 폴더 (auth, detail, home, mypage, settings)
    detail/growth/  # 성장 기록 모델 · Supabase 저장소 · 페이지
  routes/        # AppRoutes (라우트 문자열 상수)
  main.dart      # 앱 진입점 + Supabase 초기화 + 백그라운드 소음 측정 서비스
docs/            # ERD, 소셜 로그인 설정 가이드
supabase/        # schema.sql (테이블 · RLS · 마스터 데이터)
```

- 화면은 `StatefulWidget` + `http` 패키지 직접 호출 패턴 (별도 상태관리/레포지토리 계층 없음)
- 공통 스타일은 `core/constants`의 상수와 `core/widgets`의 공통 위젯으로 관리
- 네비게이션은 `AppRoutes` 상수 경유가 원칙 (일부 화면은 `MaterialPageRoute` 직접 사용도 혼재)

## 코딩 가이드라인

이 저장소는 [`CLAUDE.md`](CLAUDE.md)의 원칙(가정하지 않고 확인하기, 최소한의 변경, 외과적 수정, 검증 가능한 목표)을 따릅니다.

## 최근 변경 사항

### Supabase 연동 (이번 작업)

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

이번 라운드에서는 `home_page.dart`, `cry_analysis_page.dart`, `skin_analysis_page.dart`의 색상, `signup_page.dart`의 색상은 다른 미완성 작업(WIP)과 겹쳐 있어 의도적으로 제외했습니다.

- **성장 추이 시각화 기능 추가**: 홈 화면 "성장" 타일에서 진입. 최초 진입 시 아이 성별·생년월일을 로컬에 저장하고, 이후 키/몸무게를 기록하면 WHO 성장 표준(2006, 0~24개월) 백분위 곡선(3rd/15th/50th/85th/97th)과 우리 아이 데이터를 겹쳐서 보여줌
  - `lib/core/constants/who_growth_standards.dart`: WHO 공식 저장소([WorldHealthOrganization/anthro](https://github.com/WorldHealthOrganization/anthro))에서 가져온 체중/신장 LMS 파라미터를 내장 (월별 체크포인트, 남/녀 각각)
  - `lib/core/services/growth_calculator.dart`: LMS(Box-Cox) 공식으로 백분위 ↔ 실측값을 변환. `test/growth_calculator_test.dart`에서 WHO 공식 수치와의 일치 여부를 검증
  - `lib/features/detail/growth/`: `GrowthRecord`/`GrowthProfile` 모델, `shared_preferences` 기반 로컬 저장 서비스(백엔드 API가 아직 없어 로컬에만 저장), `GrowthRecordPage`(입력 폼 + 이력 + `fl_chart` 라인 차트)
  - `pubspec.yaml`에 `fl_chart`, `shared_preferences` 의존성 추가

## 알려진 이슈

- `lib/core/services/session_manager.dart`, `lib/features/onboarding/`는 git에 커밋된 적이 없는 미추적 파일입니다. 현재는 `login_page.dart`를 포함해 어떤 파일도 이 둘을 참조하지 않아 컴파일에는 영향이 없지만, 커밋되지 않은 채 로컬에만 남아 있는 미사용 파일입니다.
- `ApiConfig`는 현재 아무 화면도 참조하지 않습니다. 로그인/회원가입이 Supabase Auth로 넘어가면서 사용처가 사라졌고, 남은 Spring 호출(`cry_analysis_page.dart`, `skin_analysis_page.dart`)은 `http://localhost:8080`을 각자 하드코딩하고 있습니다. 이 둘을 `ApiConfig.baseUrl`로 모으는 정리가 필요합니다.
- `mypage_page.dart`의 Logout 메뉴가 `onTap: () {}` 상태입니다. `Supabase.instance.client.auth.signOut()` 연결이 필요합니다.
- 앱 재시작 시 저장된 세션을 확인하지 않고 항상 로그인 화면으로 진입합니다.
