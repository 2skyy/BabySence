# BabySense

육아 기록/모니터링 Flutter 앱 + Claude를 부르는 FastAPI 서버.
로그인·회원가입, 아이 정보 온보딩, 홈 대시보드, 수유/체온/배변/수면/성장 기록,
소음 측정, 예방접종, 약·병원, 커뮤니티, 함께 키우기(공동 육아)로 구성됩니다.

**판정이 있는 영역은 체온·성장·소음 셋뿐입니다.** 나머지는 기록하고 집계만
합니다 — 임계값을 정한 공인 출처를 찾지 못했고, 없는 기준을 지어내는 것보다
그 편이 낫다고 판단했습니다([`docs/assessment-rules.md`](docs/assessment-rules.md)).

**이 앱은 진단하지 않습니다.** 피부 사진도 병명을 말하지 않고, 보이는 것과
단계만 돌려줍니다.

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

> ✅ **004(함께 키우기)는 2026-08-11 운영 DB에 적용됐습니다.**
> 새 DB를 만드는 경우에도 `schema.sql`에 이미 포함되어 있습니다.

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
| `POST /api/skin/diagnose` | ✅ Claude 비전. **진단하지 않습니다** |

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
> 키가 없어도 서버는 정상 기동하고 `/api/advice`·`/api/skin/diagnose`만
> 503을 반환합니다. **두 엔드포인트가 같은 키 = 같은 크레딧**을 쓰므로
> 횟수 상한을 기능별로 따로 셉니다(상담 30회/시간, 피부 10장/시간).
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

2026-08-12~13에 크게 세 덩어리가 바뀌었습니다. 각각 왜 그렇게 됐는지가
코드 주석에 남아 있습니다.

### 피부 — 진단을 그만두고 Claude 비전으로

성인 피부암 데이터셋(ISIC 계열 9종)으로 분류기를 만들려던 계획을 접었습니다.
영유아에게 거의 없는 질환들이라 **기저귀 발진 사진에 '흑색종'이 붙을 수**
있었고, 보호자가 실제로 사진을 찍는 이유(기저귀 발진·땀띠·태열·지루성
피부염)는 그 데이터에 라벨조차 없었습니다.

지금은 서버가 Claude 비전을 부르고, 돌려주는 것은 셋뿐입니다 — **보이는 것**,
**단계**(주의/상담 권장), **지금 할 수 있는 것**. 병명도 확률도 없습니다.

- `level`에 `normal`이 **없습니다.** 사진 한 장으로 '정상'이라고 말하는 것은
  안심이 아니라 반대 방향의 진단입니다. 체온은 공인 임계값이 있어 정상을
  말할 수 있지만 사진에는 그 근거가 없습니다.
- 응답에 `unknown` 필드가 **필수**입니다("사진으로는 가려운지 알 수 없어요").
  한 덩어리 글로 받으면 "모른다"가 가장 먼저 빠지는 문장이라, 자리를 서버가
  정해 뒀습니다.
- 모델이 낸 값을 코드가 한 번 더 잠급니다(`skin._settle`). **내리지 않고
  올리기만** 합니다 — 구조화 출력은 모양만 보장해서
  `{"level":"caution","urgent":true}`도 스키마를 통과합니다.
- 열은 사진에 없습니다. 앱이 최근 12시간 체온 기록에서 찾아 함께 보냅니다.
  생후 3개월 미만 + 발열이면 코드가 `urgent`를 켭니다.

관점 4개와 적대적 검증으로 프롬프트를 점검하다 **제가 쓴 프롬프트가 스스로
모순된 것**을 찾았습니다 — "암은 다루지 않습니다" 스무 줄 아래에 흑색종
ABCDE 기준("모양이 고르지 않은 점")과 비치유성 병변 기준이 남아 있었습니다.

### 소음 — 원시 로그를 버리고 메모리 집계로

`sleep_noise_logs`에 1초마다 한 행씩 쌓았습니다. 하룻밤이면 **28,800행**입니다.
그런데 그 로그를 읽는 곳은 평균·최대를 구하는 함수 하나뿐이었고, 인덱스
주석이 근거로 든 "그래프 조회용" 화면은 만든 적이 없습니다.

원본을 서버까지 나르려고 붙은 장치들이 이 기능의 결함을 만들었습니다 —
행 상한에 잘려 밤 통계가 '측정 직후 몇 분'이 됐던 것, 004가 2단계 RLS를
놓쳐 밤새 재고도 0건이던 것, 망이 끊기면 8시간을 재고도 결과가 없던 것.

**소음 수치는 이제 어디에도 따로 저장하지 않습니다.** 재는 동안 화면에
실시간으로 보여주고, 끝나면 앱이 메모리에서 집계해 판정 한 행에만 남깁니다
(`assessments.inputs`). 판정 경로에서 네트워크가 통째로 빠졌습니다.

'가장 컸던 소리'는 **평활 전 값**에서 셉니다. 예전에는 이동평균(이전 85% +
새 값 15%)을 거친 값에서 세어, 배경 40dB에 90dB가 한 번 들어와도 45.25dB로
기록됐습니다. 아이를 깨운 그 소리를 놓치고 있었습니다.

끝맺는 흐름은 여러 번 고쳤습니다 — 재진입 방어, 8초 저장 상한, 세션 일련번호,
`stopService`가 세션을 끝맺지 않던 것, 밤새 재고 아침에 중지하면 판정이
안 나오던 것.

### 백그라운드 로그인을 화면에서 분리

백그라운드 isolate가 `Supabase.initialize`를 한 번 더 부르면서 **화면 쪽과
같은 로그인 저장소**를 썼습니다. Supabase의 갱신 토큰은 한 번 쓰면 버려지는
티켓이라, 두 쪽이 같은 서랍에서 꺼내 가면 사슬이 끊깁니다.

    21시  재우기 시작. 화면이 꺼지면 화면 쪽은 갱신을 멈춤
          백그라운드만 밤새 티켓을 갈아치움
    07시  앱을 열면 화면이 몇 시간 전 티켓을 내밂 → 거절 → 로그아웃

그다음이 더 나빴습니다. 로그아웃된 채로 조회하면 오류가 아니라 **빈 목록**이
옵니다(RLS가 '이 사람 것'만 주는데 그 사람이 없으므로). 화면은 "아이 정보가
없어 결과를 만들지 못했습니다"라고 말했고, 아이는 멀쩡히 있었습니다.

지금은 백그라운드가 로그인을 스스로 관리하지 않습니다(`autoRefreshToken:
false` + `EmptyLocalStorage`). 화면이 쓰기 직전에 토큰을 실어 보냅니다.

### 로그인이 풀린 것을 듣는 곳을 하나로

위와 같은 뿌리입니다. 로그아웃되면 화면들이 "아이 정보를 먼저 등록해 주세요"
라고 말했습니다. 세션이 없으면 RLS가 오류가 아니라 **200 + 0행**을 주니까요.

`signedOut`을 듣는 곳을 만들었더니 이번에는 **두 곳이 됐습니다.** 설정 화면의
로그아웃과 `MainShell`의 리스너가 각각 로그인 화면을 세웠습니다. gotrue는
서버에 요청을 보내기 **전에** 로컬 세션을 지우고 `signedOut`을 흘리므로
리스너가 항상 먼저 돌고, HTTP 왕복을 기다리던 설정 화면이 뒤늦게 같은 이동을
한 번 더 해 방금 만든 화면을 지우고 다시 만들었습니다. 망이 나쁘면 그 위에
"로그아웃하지 못했습니다"까지 얹혔습니다 — 세션은 이미 지워진 뒤인데요.

`MainShell`에 달았던 것도 틀린 자리였습니다. `AuthGate`가 아이 없는 사용자를
온보딩으로 **직접** 보내므로 그 화면에서는 `MainShell`이 만들어지지 않습니다.
갓 가입한 사람이 아이 정보를 적는 동안 세션이 풀리면 아무도 보내지 않았고,
입력을 마치는 순간 저장이 실패했습니다. 화면마다 손으로 달면 하나씩 빠집니다.

지금은 `AuthRedirect`(`lib/core/services/auth_redirect.dart`) 하나가 앱 전체에서
듣습니다. `NavigatorObserver`를 물려받아 맨 위 라우트를 알고 있어서 이미 로그인
화면이면 다시 세우지 않고, 관찰자라 `navigator`도 딸려 오므로 이동에
`GlobalKey`가 따로 필요 없습니다.

인증 구독 두 곳에 `onError`도 달았습니다. gotrue 문서가 못 박아 둔 것입니다 —
이 흐름은 `BehaviorSubject`라 캐시한 에러를 새 구독자에게 그대로 다시 흘립니다.

### 그 밖

- **상담 입구를 홈 하나로.** 기록 화면 한가운데 전면 버튼 → 앱바 아이콘 →
  홈 오른쪽 아래 원형 단추로 두 번 옮겼습니다. 기록하는 중에 눈에 띄면
  방해가 되고, 방해가 안 되면 안 보였습니다. 입구가 하나이므로 그 대화는
  체온·수유·배변·수면·약병원 기록을 **전부** 맥락으로 받습니다.
- **`order()` 방향 누락 넷.** postgrest의 기본값이 내림차순인데 네 곳이
  오름차순인 줄 알고 썼습니다. 함께 키우기가 조용히 무효가 됐고, **출생 시
  몸무게가 '최근 성장 기록'으로** 상담에 나갔습니다.
- **수유 알림이 Android에서 아예 안 떴습니다.** 매니페스트에 리시버가 없어
  브로드캐스트가 예외도 로그도 없이 버려졌습니다.
- **기록 삭제에 확인 창.** 휴지통 한 번 탭이면 되돌릴 수 없었습니다.
- **완료한 접종은 눌러도 사라지지 않습니다.** 탭하면 날짜 수정, 되돌리기는
  길게 눌러 확인 창을 거칩니다.
- **탭이 굳던 것.** `IndexedStack`이라 `initState`가 한 번만 돌아, 방금 남긴
  기록이 '없음'으로 보였습니다. `RefreshSignal`을 탭마다 하나씩 두고
  보이는 탭에만 울립니다.
- **하루 평균을 7로 고정해 나누던 것.** 오늘 가입해 다섯 번 수유하면
  "하루 평균 0.7회"였습니다.

## 앞으로 해야 할 일

세부 목록 두 곳에 있습니다.

- [`docs/remaining-work.md`](docs/remaining-work.md) — 기기에서 확인할 것,
  알려진 문제, 배포 전 준비
- [`docs/review-findings.md`](docs/review-findings.md) — 2026-08-13 전체
  검토에서 나온 39건. 각 항목에 **앱에서 확인하는 방법**이 붙어 있습니다

### 제가 할 수 없는 것

| 할 일 | 왜 |
|---|---|
| **마이크 −15dB 보정 확인** | 실제 소음계가 필요합니다. **소음 기능 전체가 이 값 위에 서 있습니다** |
| **기기 확인 13가지** | 알림·마이크·카메라는 시뮬레이터로 믿을 수 없습니다 |
| **FCM 설정 파일** | `google-services.json` / `GoogleService-Info.plist` |
| **소셜 로그인** | Supabase 대시보드에서 Google·Kakao 활성화 |
| **논문 원고 수정** | `.docx`가 저장소에 없습니다 |

### 기기에서 먼저 볼 것

1. **밤새 소음 측정** — 저녁에 시작 → 앱 나감 → **아침에 들어와 중지**.
   여기서 판정이 안 나오던 적이 있습니다. 로그아웃도 확인하세요
2. **수유 알림** — 매니페스트를 고쳤지만 실제로 뜨는지는 못 봤습니다
3. **함께 키우기** — 계정 두 개로 초대 → 수락 → **기록까지** 보이는지
4. **다크 모드** — 검토에서 5건이 나왔는데 아직 안 고쳤습니다

### 아직 안 고친 것

- **다크 모드 5건.** 기존 골든 테스트가 primary '위의' 흰 글씨만 봐서,
  primary를 **전경으로** 쓰는 38곳이 검증된 적이 없습니다
- **ERD 명세** 19개 중 12개만 채워져 있고, `docs/erd-en.svg`는 손으로 그린
  그림이라 `sleep_noise_logs` 상자가 남아 있습니다
- **`test/silent_failure_test.dart`가 플래그 이름만 봅니다.** 실패 경로에서
  실제로 켜지는지 보는 쪽으로 옮겨야 같은 종류를 계속 잡습니다

### 정리 대상

운영 Supabase의 테스트 계정들(`community-*`, `mig-check-*`, `share-check-*`
등), 로컬 PostgreSQL(`brew uninstall postgresql@16` — 마이그레이션을 운영에
넣기 전에 돌려 볼 곳이라 논문이 끝난 뒤에).

## 검증 상태

**자동 테스트 — Flutter 568건 / 서버 103건**

`flutter test`, `cd server && ./venv/bin/python -m pytest`.
`flutter analyze`는 경고 0건입니다.

이 저장소의 테스트에는 **소스를 글자로 읽어 확인하는 것**이 섞여 있습니다.
화면 코드에 위젯 테스트를 붙이기 어려운 자리가 많은데, 거기서 되돌아가면
사용자가 데이터를 잃기 때문입니다. 예:

- `test/query_order_test.dart` — 방향 없는 `.order(`를 막습니다.
  한 곳을 고치려고 쓴 테스트가 **나머지 셋을 찾았습니다**
- `test/silent_failure_test.dart` — 조회 실패를 '기록 없음'으로 보여주지
  않는지
- `test/background_auth_test.dart` — 백그라운드가 로그인 저장소를 공유하지
  않는지

글자로 읽는 방식의 한계도 겪었습니다. 로그인 화면으로 **두 번** 보내던 결함을
그 테스트들은 하나도 잡지 못했습니다 — 찾던 문자열은 멀쩡히 다 있었으니까요.
그래서 인증 쪽은 실제로 돌리는 테스트로 옮겼습니다:

- `test/core/services/auth_redirect_test.dart` — 가짜 흐름을 물려 **화면 전환을
  직접 확인합니다.** 로그인 화면으로 정말 가는지, 두 번 가지 않는지, 흐름에
  실린 오류가 앱을 죽이지 않는지. 가드와 `onError`를 각각 빼고 돌려 이 테스트가
  깨지는 것까지 확인했습니다(그래야 테스트가 비어 있지 않다는 뜻이므로)

`AuthRedirect`가 Supabase에 직접 붙지 않고 흐름을 **받기만** 하도록 만든 것이
이걸 가능하게 했습니다. 앞으로 인증 주변을 고칠 때는 이 자리를 쓰면 됩니다.

**운영 DB에 직접 확인 (2026-08-13)**

001–011 마이그레이션이 전부 적용됐습니다. REST로 직접 물어 확인했습니다 —
`sleep_noise_logs`가 404(PGRST205), `sleep_noise_stats()`가 404(PGRST202),
`skin_analyses.disease_result`가 42703.

**로컬 PostgreSQL**

010·011을 두 번 적용해도 되는지, 마이그레이션 경로와 `schema.sql` 단독
경로가 같은 결과(표 19 · 정책 32 · 함수 8)를 내는지 확인했습니다.

**실제 API 호출**

피부 분석을 한 번 실제로 불러 경로 전체를 확인했습니다. 그 과정에서
구조화 출력이 `maxItems`를 받지 않는다는 것(400)을 발견해 고쳤습니다.

**확인됨 (실기기)**

- 소음 측정을 시작하면 `sleep_records`에 행이 생기고 `sleep_type`이 화면에서
  고른 값과 일치합니다. 백그라운드 isolate의 Supabase 초기화가 동작한다는
  뜻이기도 합니다.

**확인됨 (iOS 시뮬레이터, 2026-08-06)**

- iPhone 17 Pro에서 빌드·실행, Supabase 세션 복원, 마이크 권한 요청 정상.
- Firebase는 설정 파일이 없어 초기화가 실패하지만 **앱은 계속 동작합니다.**

**확인 못 한 것**

- Android APK 빌드 — 이 개발 머신에 Android SDK가 없습니다.
  매니페스트는 XML 유효성과 리시버 클래스 존재까지 대조했지만, Gradle 병합은
  `flutter run` 할 때 확인됩니다.

## 플랫폼 차이

- iOS는 `BGAppRefreshTask` 기반이라 **연속 소음 측정이 불가능**합니다. Android는
  foreground service로 계속 측정할 수 있습니다. 두 플랫폼의 기능을 동일하게 문서화하면 안 됩니다.
