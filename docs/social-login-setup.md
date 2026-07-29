# 소셜 로그인 설정 가이드 (구글 · 카카오)

앱 코드는 이미 다 붙어 있습니다. 아래 콘솔 설정만 마치면 버튼이 동작합니다.

**동작 방식**: 버튼을 누르면 브라우저가 열려 각 서비스 로그인 페이지로 이동하고,
로그인을 마치면 `babysense://login-callback` 딥링크로 앱에 돌아옵니다.
client ID를 앱 코드에 넣지 않으므로, 아래 설정은 전부 각 서비스 콘솔과 Supabase 대시보드에서만 이뤄집니다.

미리 알아둘 것: **소셜 로그인은 가입과 로그인이 구분되지 않습니다.** 처음 누르는 사용자는
그 자리에서 계정이 만들어지고 `handle_new_user` 트리거가 `profiles`를 채웁니다.

---

## 0. 먼저 할 것 — 트리거 다시 실행

`schema.sql`을 이미 실행하셨다면, `handle_new_user` 함수를 **한 번 더 실행해야 합니다.**
기존 트리거는 이메일 가입의 `name` 키만 읽어서, 소셜 로그인 사용자의 이름이 빈 값으로 들어갑니다.

Supabase → SQL Editor에서 [supabase/schema.sql](../supabase/schema.sql)의
**1번 섹션 `handle_new_user` 함수 부분**만 복사해 실행하세요.
`create or replace`라서 몇 번을 실행해도 안전합니다.

이름이 담기는 키가 가입 경로마다 다른 것이 이유입니다.

| 가입 경로 | 이름이 들어오는 키 |
|---|---|
| 이메일 | `name` |
| 구글 | `full_name` (또는 `name`) |
| 카카오 | `nickname` (또는 `user_name`) |

---

## 1. Supabase — 딥링크 주소 등록

**Authentication → URL Configuration → Redirect URLs**에 아래를 추가하고 저장하세요.

```
babysense://login-callback
```

이 주소는 세 곳이 정확히 같아야 합니다.

| 위치 | 값 |
|---|---|
| Supabase Redirect URLs | `babysense://login-callback` |
| [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) intent-filter | scheme=`babysense`, host=`login-callback` |
| [login_page.dart](../lib/features/auth/login/login_page.dart)의 `_oauthRedirectUrl` | `babysense://login-callback` |

---

## 2. 구글 설정

### 2-1. Google Cloud Console

1. [console.cloud.google.com](https://console.cloud.google.com) 접속 → 새 프로젝트 생성
2. **APIs & Services → OAuth consent screen**
   - User Type: **External** 선택
   - 앱 이름, 사용자 지원 이메일, 개발자 연락처 입력 후 저장
   - 테스트 상태로 두면 **Test users에 등록한 계정만 로그인할 수 있습니다.** 팀원 계정을 모두 추가해두세요.
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type: **Web application** 선택 (Android가 아닙니다 — 브라우저 리디렉트 방식이라 웹 클라이언트만 필요합니다)
   - **Authorized redirect URIs**에 추가:
     ```
     https://sqebctxmwvyxkpbyqrfo.supabase.co/auth/v1/callback
     ```
   - 생성 후 **Client ID**와 **Client Secret** 복사

### 2-2. Supabase

**Authentication → Sign In / Providers → Google**
- Enable 켜기
- 위에서 복사한 Client ID / Client Secret 붙여넣기 → 저장

> 나중에 UX를 더 매끄럽게 하려면 `google_sign_in` 패키지로 네이티브 방식(브라우저 없이 앱 안에서 계정 선택 시트)으로 바꿀 수 있습니다. 그때는 Android용 OAuth 클라이언트와 SHA-1 지문 등록이 추가로 필요합니다.

---

## 3. 카카오 설정

### 3-1. Kakao Developers

1. [developers.kakao.com](https://developers.kakao.com) → **내 애플리케이션 → 애플리케이션 추가하기**
2. **앱 설정 → 앱 키**에서 **REST API 키** 복사
3. **제품 설정 → 카카오 로그인** → 활성화 **ON**
4. 같은 화면의 **Redirect URI**에 추가:
   ```
   https://sqebctxmwvyxkpbyqrfo.supabase.co/auth/v1/callback
   ```
5. **제품 설정 → 카카오 로그인 → 보안** → **Client Secret** 생성 후 활성화 상태 **ON**
6. **제품 설정 → 카카오 로그인 → 동의항목** → **닉네임**을 필수 동의로 설정

### 3-2. Supabase

**Authentication → Sign In / Providers → Kakao**
- Enable 켜기
- **Client ID 칸에 REST API 키**를 입력 (앱 키 중 REST API 키입니다)
- Client Secret 입력 → 저장

> **이메일 동의항목은 막힐 수 있습니다.** 카카오는 이메일 수집에 비즈니스 앱 전환이나 검수를 요구하는 경우가 있습니다. 이메일 없이 가입되어도 앱은 정상 동작합니다 — 트리거가 닉네임을 이름으로 쓰도록 되어 있습니다. 다만 `auth.users.email`이 비게 되니 나중에 이메일 기준으로 뭔가를 처리하는 기능을 붙일 때 유의하세요.

---

## 4. 테스트

```bash
flutter run --dart-define-from-file=env.json
```

1. 로그인 화면에서 카카오 또는 구글 버튼 탭
2. 브라우저가 열리고 로그인 페이지 표시
3. 로그인 완료 → 앱으로 자동 복귀 → 홈 화면
4. Supabase **Table Editor → profiles**에 행이 생기고 `name`이 채워졌는지 확인

### 잘 안 될 때

| 증상 | 확인할 것 |
|---|---|
| 브라우저가 열리는데 앱으로 안 돌아옴 | Supabase Redirect URLs에 `babysense://login-callback` 등록했는지 |
| "redirect_uri_mismatch" 에러 | 구글/카카오 콘솔의 Redirect URI가 `https://sqebctxmwvyxkpbyqrfo.supabase.co/auth/v1/callback`와 정확히 일치하는지 (끝의 `/` 포함 여부까지) |
| 구글에서 "액세스 차단됨" | OAuth consent screen의 Test users에 그 계정이 등록됐는지 |
| 홈에는 갔는데 `profiles.name`이 비어 있음 | 0번 트리거 재실행을 했는지 |
| 앱으로 돌아왔는데 로그인 화면 그대로 | `AndroidManifest.xml`의 intent-filter 추가 후 **다시 빌드**했는지 (핫 리로드로는 반영되지 않습니다) |

---

## 5. 애플 로그인 (보류)

**Apple Developer Program 연 $99 결제가 필요해 보류했습니다.**
현재 애플 버튼을 누르면 "iOS 배포 시 지원 예정입니다" 안내가 뜹니다
([login_page.dart](../lib/features/auth/login/login_page.dart)의 `handleApplePending`).

나중에 진행하실 때 필요한 것:
- Apple Developer Program 가입
- Identifiers에서 App ID와 Services ID 생성, Sign in with Apple 활성화
- Sign in with Apple용 Key 생성 (`.p8` 파일)
- Supabase → Providers → Apple에 Services ID / Team ID / Key ID / `.p8` 내용 입력
- `handleApplePending`을 `handleSocialLogin(OAuthProvider.apple)`로 교체

안드로이드에서는 네이티브 지원이 없어 브라우저 리디렉트 방식으로만 동작합니다.
