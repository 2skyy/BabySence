# 분석 서버를 AWS EC2에 올리기

앱은 기록·인증을 Supabase와 직접 주고받고, **피부 분석과 상담 답변만**
이 서버(`server/`, FastAPI)를 거칩니다. 지금까지는 개발 PC에서만 돌아서
케이블을 뽑으면 앱의 두 기능이 죽었습니다. 이 문서는 그 서버를 EC2 한 대에
올려 어디서든 붙게 하는 절차입니다.

서버는 파이썬 패키지 6개짜리라 가볍습니다. **프리 티어(t2.micro / t3.micro)로
충분**하고, 계정 생성 12개월 안에는 요금이 나오지 않습니다.

---

## 0. 준비물

- AWS 계정 (만들어 둔 것)
- `ANTHROPIC_API_KEY` — 서버가 Claude를 부를 때 씁니다. **저장소에 넣지 않습니다.**
- `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` — 프로젝트 루트 `env.json`의 값과 같습니다.

---

## 1. 인스턴스 만들기 (AWS 콘솔)

콘솔 오른쪽 위 리전을 **아시아 태평양(서울) ap-northeast-2**로 맞춘 뒤
**EC2 → 인스턴스 시작**.

| 항목 | 값 |
|---|---|
| 이름 | `babysense-server` |
| AMI | **Ubuntu Server 24.04 LTS** (프리 티어 사용 가능 표시 확인) |
| 인스턴스 유형 | **t2.micro** 또는 t3.micro — "프리 티어 사용 가능"이 붙은 것 |
| 키 페어 | "새 키 페어 생성" → `.pem` 내려받아 보관 (터미널 접속용. 브라우저 접속만 쓸 거면 없어도 됨) |
| 네트워크 설정 → 보안 그룹 | 아래 규칙 두 개 |
| 스토리지 | 기본 8GB 그대로 |

보안 그룹 인바운드 규칙:

| 유형 | 포트 | 소스 | 용도 |
|---|---|---|---|
| SSH | 22 | **내 IP** | 관리 접속 |
| 사용자 지정 TCP | **8000** | 0.0.0.0/0 | 앱이 서버를 부르는 포트 |

8000을 전체 공개해도 되는 이유: 서버가 요청마다 Supabase 로그인 토큰을
검사하고(`app/auth.py`), 사용자별·전체 호출 상한이 걸려 있습니다
(`ADVICE_RATE_LIMIT` 등). 로그인 없이 부르면 401입니다.

**인스턴스 시작** 누르면 1~2분 뒤 "실행 중"이 됩니다.

### 주소 고정 (권장)

인스턴스를 껐다 켜면 퍼블릭 IP가 바뀌어 앱의 서버 주소도 매번 바뀝니다.
**EC2 → 탄력적 IP → 할당 → 인스턴스에 연결**로 고정하세요. 실행 중인
인스턴스에 붙어 있는 동안은 무료입니다.

---

## 2. 접속해서 설치

**EC2 → 인스턴스 선택 → 연결 → "EC2 Instance Connect" → 연결**을 누르면
브라우저에 터미널이 열립니다. `.pem` 없이도 됩니다.

터미널에서 순서대로:

```bash
git clone https://github.com/2skyy/BabySence.git
```

> 저장소가 비공개면 GitHub 로그인이 필요합니다. 그때는 GitHub →
> Settings → Developer settings → Personal access tokens에서 `repo` 권한
> 토큰을 만들고, 사용자명/비밀번호 자리에 GitHub ID / 토큰을 넣습니다.

```bash
nano ~/BabySence/server/.env
```

아래 세 줄을 채워 넣고 저장(`Ctrl+O`, `Enter`, `Ctrl+X`):

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
SUPABASE_URL=https://sqebctxmwvyxkpbyqrfo.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

```bash
bash ~/BabySence/deploy/ec2-setup.sh
```

스크립트가 파이썬 가상환경을 만들고 패키지를 깔고, 서버를 **systemd
서비스**로 등록합니다. 끝에 이런 줄이 보이면 성공입니다:

```
{"status":"ok","models":{"skin":{"ready":true},"advice":{"ready":true}}}
```

서비스로 올렸으므로 터미널을 닫아도, 인스턴스를 재부팅해도 서버는 스스로
다시 뜹니다.

---

## 3. 밖에서 확인

내 PC나 폰 브라우저에서 (IP는 콘솔의 퍼블릭 IPv4 / 탄력적 IP):

```
http://<서버 IP>:8000/health
```

위와 같은 JSON이 보이면 끝입니다. 안 보이면 십중팔구 보안 그룹의 8000
규칙이 빠진 것입니다.

---

## 4. 앱을 이 서버로 붙이기

앱 코드는 바꿀 것이 없습니다. 실행할 때 주소만 넘깁니다:

```bash
flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://<서버 IP>:8000
```

이제 USB 터널(`adb reverse`)도, 같은 와이파이도 필요 없습니다.

---

## 5. 운영 명령 모음

| 하고 싶은 것 | 명령 |
|---|---|
| 상태 보기 | `systemctl status babysense-server` |
| 실시간 로그 | `journalctl -u babysense-server -f` |
| 재시작 (`.env` 바꾼 뒤) | `sudo systemctl restart babysense-server` |
| 코드 갱신 후 반영 | `cd ~/BabySence && git pull && bash deploy/ec2-setup.sh` |
| 서버 끄기 | `sudo systemctl stop babysense-server` |

---

## 6. 아직 안 한 것 — 알고 계셔야 합니다

**HTTPS가 아닙니다.** 지금은 `http://`라서 앱의 **디버그 빌드**에서만
붙습니다(`android/app/src/debug/AndroidManifest.xml`이 평문 통신을 허용).
스토어에 올리는 릴리스 빌드는 안드로이드가 `http://`를 막습니다.

심사 시연은 디버그 빌드로 충분하지만, 릴리스까지 가려면 도메인 하나가
필요합니다(무료 DuckDNS도 됨). 그 뒤 EC2에 Caddy를 얹으면 인증서까지
자동입니다. 그건 별도 작업으로 두었습니다.

**요금**: 프리 티어 12개월이 지나면 t2.micro가 월 1만 원 안팎입니다.
졸업 후 쓰지 않을 거면 **인스턴스 종료**로 지우세요. 탄력적 IP는 인스턴스에
붙어 있지 않으면 시간당 소액이 나오니 같이 해제해야 합니다.
