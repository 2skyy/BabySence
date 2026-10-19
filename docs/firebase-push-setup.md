# Firebase 푸시 알림(FCM) 설정

앱 쪽 코드는 **이미 다 들어가 있습니다.** 남은 것은 Firebase 콘솔에서 설정
파일을 받아 넣는 일과, 보내는 쪽을 만드는 일입니다.

## 먼저 — 이게 필요한 알림인지

| | 로컬 알림 | FCM 푸시 |
|---|---|---|
| 수유·예방접종 시간 | **이쪽** | 필요 없음 |
| 댓글·공지·다른 보호자의 기록 | 불가능 | **이쪽** |
| 인터넷 | 없어도 됨 | 필요 |
| 서버 | 없어도 됨 | 필요 |

시각이 정해진 알림은 폰이 스스로 울리면 됩니다. FCM은 **기기가 미리 알 수
없는 일**에만 씁니다. 설정을 안 해도 수유·예방접종 알림은 그대로 동작합니다.

## 1. Firebase 프로젝트 만들기

1. [console.firebase.google.com](https://console.firebase.google.com) → 프로젝트 추가
2. Android 앱 추가
   - 패키지 이름: **`com.example.flutter_project`**
     (`android/app/build.gradle.kts`의 `namespace`와 **정확히** 같아야 합니다)
   - 닉네임·SHA-1은 비워도 됩니다 (푸시에는 필요 없습니다)
3. **`google-services.json` 내려받기**
4. `android/app/google-services.json`에 넣기

파일을 넣으면 Gradle이 알아서 켭니다 — `android/app/build.gradle.kts`가 파일이
있을 때만 플러그인을 켜도록 되어 있습니다. 없으면 그냥 넘어가므로, 설정하지
않은 팀원도 빌드할 수 있습니다.

**이 파일은 저장소에 올리지 마세요.** `.gitignore`에 넣어 두었습니다.

## 2. 확인

앱을 다시 빌드하고(`flutter clean` 후 실행) 로그를 봅니다.

```
Firebase 초기화 성공
```

이게 안 뜨고 실패가 뜨면 파일 위치나 패키지 이름이 틀린 것입니다.

## 3. 보내 보기

Firebase 콘솔 → **Messaging** → 캠페인 만들기 → 알림.

특정 기기에만 보내려면 **테스트 메시지**에 토큰을 넣습니다. 토큰은 Supabase의
`device_tokens` 표에서 볼 수 있습니다 — 로그인하면 앱이 자동으로 저장합니다.

| 앱 상태 | 누가 알림을 그리나 |
|---|---|
| 열려 있음 | 앱이 직접 (`PushService._showForeground`) |
| 뒤에 있음 · 꺼져 있음 | 안드로이드가 알아서 |

## 4. 서버에서 보내기 (아직 없음)

콘솔에서 손으로 보내는 것 말고 **자동으로** 보내려면 보내는 쪽이 필요합니다.
Supabase Edge Function이 자연스러운 자리입니다.

```
댓글 저장 → DB 트리거 → Edge Function → FCM → 글쓴이 기기
```

Edge Function은 다음을 합니다.

1. 글쓴이의 `user_id`로 `device_tokens`에서 토큰을 찾습니다
2. FCM HTTP v1 API로 보냅니다
3. `UNREGISTERED` 응답이 오면 그 토큰 행을 지웁니다 (앱을 지운 기기)

FCM v1은 **서비스 계정 키**로 인증합니다. Firebase 콘솔 → 프로젝트 설정 →
서비스 계정에서 받아, Edge Function의 secret으로 넣습니다. **앱에는 절대 넣지
마세요** — 그 키가 있으면 누구에게나 알림을 보낼 수 있습니다.

## 앱이 이미 하는 일

`lib/core/services/push_service.dart`

- 로그인하면 이 기기의 토큰을 `device_tokens`에 저장
- 토큰이 새로 발급되면 갱신 (`onTokenRefresh`)
- **로그아웃하면 지움** — 안 지우면 이 폰으로 다음에 로그인한 사람에게
  앞사람 알림이 갑니다
- 앱이 열려 있을 때 도착한 알림을 직접 띄움

`lib/main.dart`

- `firebaseBackgroundHandler` — 앱이 꺼져 있을 때 도착한 것을 받는 손.
  **알림을 그리지 않습니다** (안드로이드가 이미 그립니다 — 여기서 또 띄우면
  두 번 뜹니다)

## 알림 id

한 플러그인이 여러 알림을 다루므로 자리를 나눠 씁니다.

| | id |
|---|---|
| 배경 서비스(소음·백색소음) | 888 |
| 수유 알림 | 2001 |
| 예방접종 알림 | 3001~3030 |
| **푸시** | **5000~5999** |
| 알림 시험 | 9001 |
