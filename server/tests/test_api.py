"""/api/advice 엔드포인트.

Claude를 부르지 않습니다. 확인하는 것은 **모델에 닿기 전에 무엇이 걸러지는가**
입니다 — 인증, 횟수 상한, 요청 모양.
"""

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import advice, auth, main  # noqa: E402

client = TestClient(main.app)

QUESTION = {
    "messages": [{"role": "user", "content": "열이 나요"}],
    "domain": "temperature",
}
AUTHED = {"Authorization": "Bearer token"}


@pytest.fixture(autouse=True)
def clean_state():
    """테스트끼리 상한 기록과 인증 우회가 새지 않게 합니다."""
    main._per_user_limit._hits.clear()
    main._global_limit._hits.clear()
    main.app.dependency_overrides.clear()
    yield
    main.app.dependency_overrides.clear()


@pytest.fixture
def logged_in():
    main.app.dependency_overrides[auth.require_user] = lambda: "user-1"


@pytest.fixture
def answers(monkeypatch):
    """Claude 대신 고정 답변을 돌려줍니다."""

    def fake(**kwargs):
        return advice.Answer(text="충분히 재워 주세요.", truncated=False)

    monkeypatch.setattr(advice.client, "ask", fake)
    return fake


class TestAuthRequired:
    """크레딧을 쓰는 엔드포인트라 로그인 없이는 닿지 않아야 합니다."""

    def test_rejects_anonymous(self):
        assert client.post("/api/advice", json=QUESTION).status_code == 401

    def test_rejects_wrong_scheme(self):
        response = client.post(
            "/api/advice", json=QUESTION, headers={"Authorization": "Basic xyz"}
        )
        assert response.status_code == 401

    def test_does_not_call_claude_when_anonymous(self, monkeypatch):
        called = []
        monkeypatch.setattr(
            advice.client, "ask", lambda **kw: called.append(1) or advice.Answer("", False)
        )
        client.post("/api/advice", json=QUESTION)
        assert called == []

    def test_health_stays_open(self):
        # 서버가 살아 있는지 보는 것까지 막을 이유는 없습니다.
        assert client.get("/health").status_code == 200


class TestAnswer:
    def test_returns_the_answer(self, logged_in, answers):
        response = client.post("/api/advice", json=QUESTION, headers=AUTHED)
        assert response.status_code == 200
        assert response.json()["answer"] == "충분히 재워 주세요."

    def test_server_attaches_the_disclaimer(self, logged_in, answers):
        body = client.post("/api/advice", json=QUESTION, headers=AUTHED).json()
        assert body["disclaimer"] == advice.DISCLAIMER

    def test_reports_a_truncated_answer(self, logged_in, monkeypatch):
        # 끊긴 답을 완성된 답처럼 내려보내면 앱이 그대로 보여줍니다.
        monkeypatch.setattr(
            advice.client,
            "ask",
            lambda **kw: advice.Answer(text="열이 날 때는", truncated=True),
        )
        body = client.post("/api/advice", json=QUESTION, headers=AUTHED).json()
        assert body["truncated"] is True

    def test_marks_a_complete_answer_as_such(self, logged_in, answers):
        body = client.post("/api/advice", json=QUESTION, headers=AUTHED).json()
        assert body["truncated"] is False


class TestRequestShape:
    def test_rejects_unknown_domain(self, logged_in, answers):
        response = client.post(
            "/api/advice", json={**QUESTION, "domain": "요리"}, headers=AUTHED
        )
        assert response.status_code == 400

    def test_rejects_conversation_ending_in_an_answer(self, logged_in, answers):
        response = client.post(
            "/api/advice",
            json={"messages": [{"role": "assistant", "content": "네"}]},
            headers=AUTHED,
        )
        assert response.status_code == 400

    def test_rejects_too_long_a_conversation(self, logged_in, answers):
        messages = [{"role": "user", "content": "질문"} for _ in range(200)]
        response = client.post(
            "/api/advice", json={"messages": messages}, headers=AUTHED
        )
        assert response.status_code == 413


class TestRateLimit:
    def test_blocks_a_user_past_the_limit(self, logged_in, answers, monkeypatch):
        monkeypatch.setattr(main._per_user_limit, "_limit", 2)

        for _ in range(2):
            assert client.post("/api/advice", json=QUESTION, headers=AUTHED).status_code == 200

        blocked = client.post("/api/advice", json=QUESTION, headers=AUTHED)
        assert blocked.status_code == 429
        assert "Retry-After" in blocked.headers

    def test_does_not_call_claude_when_blocked(self, logged_in, monkeypatch):
        calls = []
        monkeypatch.setattr(
            advice.client,
            "ask",
            lambda **kw: calls.append(1) or advice.Answer("답", False),
        )
        monkeypatch.setattr(main._per_user_limit, "_limit", 1)

        client.post("/api/advice", json=QUESTION, headers=AUTHED)
        client.post("/api/advice", json=QUESTION, headers=AUTHED)
        assert len(calls) == 1

    def test_global_limit_catches_many_accounts(self, answers, monkeypatch):
        # 계정은 얼마든지 새로 만들 수 있어 사용자별 상한만으로는 총액이
        # 막히지 않습니다.
        monkeypatch.setattr(main._global_limit, "_limit", 3)

        for i in range(3):
            main.app.dependency_overrides[auth.require_user] = lambda i=i: f"user-{i}"
            assert client.post("/api/advice", json=QUESTION, headers=AUTHED).status_code == 200

        main.app.dependency_overrides[auth.require_user] = lambda: "user-new"
        assert client.post("/api/advice", json=QUESTION, headers=AUTHED).status_code == 429


class TestCors:
    def test_does_not_echo_arbitrary_origins(self):
        # 예전에는 allow_origins=["*"] + allow_credentials=True였습니다.
        # 그 조합에서는 요청이 보낸 Origin을 그대로 되돌려줍니다.
        response = client.get("/health", headers={"Origin": "https://evil.example"})
        assert "access-control-allow-origin" not in response.headers
