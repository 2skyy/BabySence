# BabySense

육아 기록/모니터링 Flutter 앱. 로그인·회원가입, 아이 정보 온보딩, 홈 대시보드(소음·피부·울음 분석), 수유/체온/배변/수면/성장 기록, 예방접종, 마이페이지/설정 기능으로 구성됩니다. 다른 육아 앱 대비 차별점은 **피부 AI 분석**이며, 성장 추이 시각화 등 나머지 기능은 하나씩 채워가는 중입니다.

## 프로젝트 구조

```
lib/
  core/
    constants/   # AppColors, AppRadius, AppSpacing, AppTextStyles, ApiConfig, WhoGrowthStandards
    services/    # SessionManager(SharedPreferences 래퍼), NoiseTracker, GrowthCalculator
    theme/       # AppTheme
    widgets/     # CommonButton, CommonTextField, CommonAppBar
  features/      # 화면 단위 폴더 (auth, detail, home, mypage, onboarding, settings)
    detail/growth/  # 성장 기록 모델 · 로컬 저장소 · 페이지
  routes/        # AppRoutes (라우트 문자열 상수)
  main.dart      # 앱 진입점 + 백그라운드 소음 측정 서비스 초기화
```

- 화면은 `StatefulWidget` + `http` 패키지 직접 호출 패턴 (별도 상태관리/레포지토리 계층 없음)
- 공통 스타일은 `core/constants`의 상수와 `core/widgets`의 공통 위젯으로 관리
- 네비게이션은 `AppRoutes` 상수 경유가 원칙 (일부 화면은 `MaterialPageRoute` 직접 사용도 혼재)

## 코딩 가이드라인

이 저장소는 [`CLAUDE.md`](CLAUDE.md)의 원칙(가정하지 않고 확인하기, 최소한의 변경, 외과적 수정, 검증 가능한 목표)을 따릅니다.

## 최근 변경 사항

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
- `login_page.dart`의 `_baseUrl`이 `http://127.0.0.1:8080`로 하드코딩되어 있습니다(팀원이 로컬 개발용으로 임시 수정한 것으로 보임). 이전에는 플랫폼별로 분기하는 `ApiConfig.baseUrl`을 사용했습니다.
