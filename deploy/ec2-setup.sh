#!/usr/bin/env bash
# EC2(Ubuntu 24.04)에서 분석 서버를 systemd 서비스로 올립니다.
#
# 전제: 이 저장소가 ~/BabySence 에 clone 되어 있고, server/.env 가 채워져 있음.
# 실행:  bash ~/BabySence/deploy/ec2-setup.sh
# 다시 실행해도 안전합니다(설치는 건너뛰고 서비스만 재시작).
set -euo pipefail

REPO="$HOME/BabySence"
SERVER="$REPO/server"
UNIT=/etc/systemd/system/babysense-server.service

if [ ! -f "$SERVER/.env" ]; then
  echo "server/.env 가 없습니다. ANTHROPIC_API_KEY 등을 먼저 적어 주세요." >&2
  exit 1
fi

sudo apt-get update -qq
sudo apt-get install -y -qq python3-venv git

cd "$SERVER"
[ -d venv ] || python3 -m venv venv
venv/bin/pip install -q --upgrade pip
venv/bin/pip install -q -r requirements.txt

# 서비스 파일의 홈 경로를 실제 사용자 것으로 맞춥니다.
sed "s|__HOME__|$HOME|g; s|__USER__|$USER|g" "$REPO/deploy/babysense-server.service" \
  | sudo tee "$UNIT" > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable babysense-server
sudo systemctl restart babysense-server

sleep 2
echo "---- 상태 ----"
systemctl --no-pager --lines=5 status babysense-server || true
echo "---- /health ----"
curl -s http://127.0.0.1:8000/health || echo "(아직 응답 없음 — journalctl -u babysense-server 로 로그 확인)"
echo
