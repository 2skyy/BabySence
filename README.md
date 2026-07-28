# BabySense

육아 기록/모니터링 Flutter 앱. 로그인·회원가입, 아이 정보 온보딩, 홈 대시보드(소음·피부·울음 분석), 수유/체온/배변/수면 기록, 예방접종, 마이페이지/설정 기능으로 구성됩니다.

## 프로젝트 구조

```
lib/
  core/
    constants/   # AppColors, AppRadius, AppSpacing, AppTextStyles, ApiConfig
    services/    # SessionManager(SharedPreferences 래퍼), NoiseTracker
    theme/       # AppTheme
    widgets/     # CommonButton, CommonTextField, CommonAppBar
  features/      # 화면 단위 폴더 (auth, detail, home, mypage, onboarding, settings)
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

## 알려진 이슈

- `lib/core/services/session_manager.dart`, `lib/features/onboarding/`는 git에 커밋된 적이 없는 미추적 파일입니다. 현재는 `login_page.dart`를 포함해 어떤 파일도 이 둘을 참조하지 않아 컴파일에는 영향이 없지만, 커밋되지 않은 채 로컬에만 남아 있는 미사용 파일입니다.
- `login_page.dart`의 `_baseUrl`이 `http://127.0.0.1:8080`로 하드코딩되어 있습니다(팀원이 로컬 개발용으로 임시 수정한 것으로 보임). 이전에는 플랫폼별로 분기하는 `ApiConfig.baseUrl`을 사용했습니다.
