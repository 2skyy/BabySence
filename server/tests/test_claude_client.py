"""Claude 호출 래퍼 — 타임아웃 정책과 서킷 브레이커.

우아콘2025 Mediator 세션에서 가져온 것: 벤더의 생존을 전제하지 않는다.
발표에 적은 수치 그대로다 — 최근 1분 오류율 50% 초과 시 열림, 60초 뒤
반열림에서 한 건만 통과, 단 표본 10건 이상일 때만 판정(규모 보정 —
요청 2건 중 1건 실패로 열리면 안 된다).
"""

import sys
from pathlib import Path

import httpx
import pytest
from anthropic import APIStatusError

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import advice, claude_client, skin  # noqa: E402
from app.claude_client import CircuitBreaker, CircuitOpen  # noqa: E402


class Clock:
    """테스트가 시간을 직접 굴립니다. 진짜 60초를 기다릴 수는 없으므로."""

    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += seconds


@pytest.fixture
def clock():
    return Clock()


@pytest.fixture
def breaker(clock):
    return CircuitBreaker(clock=clock)


def fail_n(breaker, n):
    for _ in range(n):
        breaker.record_failure()


class TestOpening:
    def test_opens_after_majority_failures(self, breaker):
        """10건 중 6건 실패(60%) → 열림."""
        for _ in range(4):
            breaker.record_success()
        fail_n(breaker, 6)
        with pytest.raises(CircuitOpen):
            breaker.check()

    def test_needs_min_samples(self, breaker):
        """표본이 10건 미만이면 전부 실패여도 판정하지 않는다.

        새벽의 내 서버는 1분에 요청이 두 건일 수도 있다. 그중 하나가
        실패했다고 문을 닫으면, 규모 검토 없이 배민의 임계치를 이식한
        셈이 된다.
        """
        fail_n(breaker, 9)
        breaker.check()  # 열리지 않아야 한다

    def test_exactly_half_stays_closed(self, breaker):
        """'50% 초과'가 기준이다. 딱 절반은 닫힌 채로 둔다."""
        for _ in range(5):
            breaker.record_success()
        fail_n(breaker, 5)
        breaker.check()

    def test_old_outcomes_fall_out_of_window(self, breaker, clock):
        """1분 창 밖의 실패는 세지 않는다."""
        fail_n(breaker, 6)
        clock.advance(61)
        for _ in range(4):
            breaker.record_success()
        breaker.check()  # 창 안에는 성공 4건뿐 — 표본 부족, 닫힘


class TestRecovery:
    def _open(self, breaker):
        fail_n(breaker, 10)
        with pytest.raises(CircuitOpen):
            breaker.check()

    def test_stays_open_during_cooldown(self, breaker, clock):
        self._open(breaker)
        clock.advance(30)
        with pytest.raises(CircuitOpen):
            breaker.check()

    def test_half_open_lets_one_probe(self, breaker, clock):
        """60초 뒤에는 한 건만 통과시켜 회복을 확인한다."""
        self._open(breaker)
        clock.advance(61)
        breaker.check()  # 정찰 한 건 — 통과
        with pytest.raises(CircuitOpen):
            breaker.check()  # 정찰이 끝나기 전 두 번째는 막는다

    def test_probe_success_closes(self, breaker, clock):
        self._open(breaker)
        clock.advance(61)
        breaker.check()
        breaker.record_success()
        breaker.check()  # 닫혔다 — 정상 통과
        breaker.check()

    def test_probe_failure_reopens(self, breaker, clock):
        """정찰이 실패하면 다시 60초를 쉰다. 장애 벤더에 트래픽을 계속
        넣으면 장애가 길어진다는 것이 이 장치의 존재 이유다."""
        self._open(breaker)
        clock.advance(61)
        breaker.check()
        breaker.record_failure()
        with pytest.raises(CircuitOpen):
            breaker.check()
        clock.advance(30)
        with pytest.raises(CircuitOpen):
            breaker.check()
        clock.advance(31)
        breaker.check()  # 다음 정찰


def status_error(code):
    request = httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    response = httpx.Response(code, request=request)
    return APIStatusError("boom", response=response, body=None)


class FailingClient:
    """messages.create가 지정한 HTTP 오류를 던지는 가짜 벤더."""

    def __init__(self, code):
        self._code = code
        outer = self

        class _Messages:
            def create(self, **kwargs):
                raise status_error(outer._code)

        self.messages = _Messages()


class Untouchable:
    """건드리면 터지는 표식. 브레이커가 열렸을 때 벤더에 손도 대지 않는지."""

    def __getattr__(self, name):
        raise AssertionError("브레이커가 열렸는데 벤더 클라이언트를 건드렸습니다")


class TestWiring:
    """발표 슬라이드 4의 검증 항목 그대로."""

    @pytest.fixture(autouse=True)
    def fresh_breaker(self, monkeypatch):
        fresh = CircuitBreaker()
        monkeypatch.setattr(claude_client, "breaker", fresh)
        return fresh

    def test_mock_500s_open_the_circuit(self, monkeypatch, fresh_breaker):
        """mock으로 500을 뱉게 해 서킷이 실제로 열리는지."""
        monkeypatch.setattr(skin.model, "_client", FailingClient(500))
        for _ in range(10):
            with pytest.raises(APIStatusError):
                skin.model._call(dummy=True)
        with pytest.raises(CircuitOpen):
            fresh_breaker.check()

    def test_400s_do_not_open_the_circuit(self, monkeypatch, fresh_breaker):
        """4xx는 벤더가 멀쩡히 응답한 것 — 장애로 세지 않는다."""
        monkeypatch.setattr(skin.model, "_client", FailingClient(400))
        for _ in range(10):
            with pytest.raises(APIStatusError):
                skin.model._call(dummy=True)
        fresh_breaker.check()  # 닫힌 채여야 한다

    def test_open_circuit_answers_instantly_without_touching_vendor(
        self, monkeypatch, fresh_breaker
    ):
        """열린 상태의 응답이 30초 로딩이 아니라 즉시 안내인지."""
        for _ in range(10):
            fresh_breaker.record_failure()

        monkeypatch.setattr(advice.client, "_client", Untouchable())
        with pytest.raises(advice.AdviceUnavailable) as e:
            advice.client.ask(
                messages=[{"role": "user", "content": "열이 나요"}],
                domain="temperature",
            )
        assert "쉬어 가" in str(e.value)

        monkeypatch.setattr(skin.model, "_client", Untouchable())
        with pytest.raises(skin.SkinModelUnavailable) as e:
            skin.model.read(b"x", "image/jpeg", age_months=5)
        assert "쉬어 가" in str(e.value)

    def test_policy_lives_in_one_place(self):
        """타임아웃 연결 5초·응답 30초, 재시도 0회 — 생성기 하나가 정한다."""
        client = claude_client.make_anthropic("sk-test")
        assert client.max_retries == 0
        assert client.timeout.connect == 5.0
        assert client.timeout.read == 30.0

    def test_skin_call_uses_the_longer_nonstreaming_timeout(self, monkeypatch):
        """피부 판독은 비스트리밍 — read 타임아웃이 생성 전체를 자르므로
        공용 30초가 아니라 60초를 쓴다. 30초로 두면 느린 정상 생성이
        요금만 내고 버려지고, 브레이커에 실패로 쌓여 상담까지 연다."""
        captured = {}

        class _Messages:
            def create(self, **kwargs):
                captured.update(kwargs)

                class _Msg:
                    pass

                return _Msg()

        class _Client:
            messages = _Messages()

        monkeypatch.setattr(skin.model, "_client", _Client())
        skin.model._call(dummy=True)
        assert captured.get("timeout") is claude_client.SKIN_TIMEOUT


class TestGuardEdges:
    """리뷰가 짚은 세 가지: 정찰 슬롯 누수, 스트리밍 중간 실패, 낙오자."""

    @pytest.fixture
    def wired(self, monkeypatch, clock):
        fresh = CircuitBreaker(clock=clock)
        monkeypatch.setattr(claude_client, "breaker", fresh)
        return fresh

    def _open(self, breaker):
        for _ in range(10):
            breaker.record_failure()

    def test_probe_slot_survives_unclassified_exception(self, wired, clock):
        """정찰이 벤더 생사와 무관한 예외로 죽어도 브레이커가 영구히
        잠기지 않는다. 잠기면 '1분 뒤 다시 시도'가 거짓이 된다."""
        self._open(wired)
        clock.advance(61)
        with pytest.raises(ValueError):
            with claude_client.guard():
                raise ValueError("SDK 검증 오류 등 — 벤더 생사와 무관")
        # 슬롯이 반납됐으므로 다음 정찰이 가능해야 한다
        wired.check()

    def test_mid_stream_httpx_error_counts_as_failure(self, wired):
        """벤더가 연결은 받고 본문 중간에 침묵하는 열화 — SDK가 감싸지
        않는 날 httpx 오류다. 안 세면 브레이커는 정확히 필요한 순간에
        열리지 않는다."""
        for _ in range(10):
            with pytest.raises(httpx.ReadTimeout):
                with claude_client.guard():
                    raise httpx.ReadTimeout("stalled mid-stream")
        with pytest.raises(CircuitOpen):
            wired.check()

    def test_straggler_success_does_not_close_an_open_circuit(self, wired):
        """열리기 전에 출발했던 요청의 뒤늦은 성공(4xx 포함)이 갓 열린
        브레이커를 닫으면, 죽은 벤더로 트래픽이 곧장 돌아간다."""
        self._open(wired)
        wired.record_success()  # 낙오자 — 정찰이 아니다
        with pytest.raises(CircuitOpen):
            wired.check()

    def test_straggler_failure_does_not_extend_cooldown(self, wired, clock):
        self._open(wired)
        clock.advance(30)
        wired.record_failure()  # 낙오자 실패 — 냉각을 늘리면 안 된다
        clock.advance(31)
        wired.check()  # 60초 약속대로 정찰 허용


class TestRouteSlotPreservation:
    """브레이커 열림 503이 호출 상한을 태우지 않는다."""

    def test_open_breaker_503_consumes_no_rate_slot(self, monkeypatch):
        from fastapi.testclient import TestClient

        from app import auth, main

        fresh = CircuitBreaker()
        for _ in range(10):
            fresh.record_failure()
        monkeypatch.setattr(claude_client, "breaker", fresh)

        main._per_user_limit._hits.clear()
        main.app.dependency_overrides[auth.require_user] = lambda: "user-slot"
        try:
            client = TestClient(main.app)
            r = client.post(
                "/api/advice",
                json={
                    "messages": [{"role": "user", "content": "열이 나요"}],
                    "domain": "temperature",
                },
                headers={"Authorization": "Bearer token"},
            )
        finally:
            main.app.dependency_overrides.clear()

        assert r.status_code == 503
        assert "쉬어 가" in r.json()["detail"]
        assert not main._per_user_limit._hits.get("user-slot"), (
            "벤더를 부르지도 않은 503이 상한을 태우면, 벤더가 회복된 뒤 "
            "그 사용자가 429에 막힙니다"
        )
