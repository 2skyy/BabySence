"""Claude(외부 벤더) 호출을 한곳으로 모으는 래퍼.

우아콘2025 Mediator 세션에서 가져온 태도: **벤더의 생존을 전제하지 않는다.**

- 타임아웃 — 연결 5초, 응답 30초. 벤더가 늘어질 때 t2.micro의 워커가
  통째로 잡혀 있으면, 그 사이 다른 보호자의 요청은 줄만 서게 된다.
- 재시도 0회 — **일부러 뺐다.** 재시도는 장애 벤더의 부하를 키워 아래
  서킷 브레이커와 상충한다. 장애 벤더에 트래픽을 계속 넣으면 장애가
  오히려 길어진다.
- 서킷 브레이커 — 최근 1분 오류율이 50%를 넘으면 호출 자체를 끊고 즉시
  한국어 안내를 돌려준다. 사용자가 30초 로딩을 보다 실패하는 대신 1초
  안에 안내를 받는 차이다. 60초 뒤 한 건만 통과시켜 회복을 확인한다.

상담과 피부 판독이 브레이커 하나를 같이 쓴다. 벤더는 하나(Anthropic)라,
한쪽에서 관측한 장애는 다른 쪽에도 유효하다.
"""

import threading
import time
from collections import deque
from contextlib import contextmanager

import httpx
from anthropic import Anthropic, APIConnectionError, APIStatusError


def make_anthropic(api_key: str) -> Anthropic:
    """상담·피부가 같은 정책의 클라이언트를 쓰게 하는 단일 생성 지점.

    SDK 기본값은 10분 타임아웃 × 재시도 2회라 최악의 경우 30분을 붙잡는다.
    앱은 60초에 포기하므로 그때는 아무도 안 기다리는 답변을 서버 혼자
    만들고 있는 셈이다.
    """
    return Anthropic(
        api_key=api_key,
        # 연결 5초: 벤더가 죽었으면 빨리 알아야 한다. 응답 30초: 이미지가
        # 들어가는 피부 판독 기준으로 넉넉하되, 앱의 60초 포기보다는 앞선다.
        timeout=httpx.Timeout(30.0, connect=5.0),
        max_retries=0,
    )


#: 피부 판독(비스트리밍) 한 건의 응답 대기.
#:
#: 상담은 스트리밍이라 30초가 '조각 사이' 대기지만, 피부 판독은
#: messages.create 비스트리밍이라 read 타임아웃이 **생성 전체** 시간을
#: 자릅니다. 이미지+추론이면 30초를 넘길 수 있고, 그때 요금은 그대로
#: 나가는데 결과만 버리는 데다 브레이커에 실패로 쌓입니다 — 느린 것을
#: 장애로 오인해 상담까지 여는 자충수가 됩니다. 앱이 60초에 포기하므로
#: 그에 맞춥니다.
SKIN_TIMEOUT = httpx.Timeout(60.0, connect=5.0)


class CircuitOpen(RuntimeError):
    """브레이커가 열려 있어 벤더를 부르지 않았다."""


class CircuitBreaker:
    """최근 1분 창의 오류율로 벤더 호출을 여닫는다.

    **표본 10건 미만이면 판정하지 않는다.** 새벽엔 1분에 요청이 두 건일
    수도 있고, 그중 하나가 실패했다고 문을 닫으면 규모 검토 없이 대규모
    시스템의 임계치를 이식한 셈이 된다.

    무엇이 '실패'인가 — 연결 실패·타임아웃·5xx처럼 **벤더가 살아 있는지를
    말해 주는 것**만이다. 4xx는 벤더가 멀쩡히 응답한 것이므로 성공으로
    센다(요청이 나빴을 뿐이다).

    한 프로세스 안에서만 센다. 지금은 서버가 한 대라 충분하다.
    """

    # 발표에 적은 값 그대로. 아무도 다르게 쓰지 않아 손잡이로 만들지 않았다.
    _WINDOW = 60.0
    _MIN_SAMPLES = 10
    _THRESHOLD = 0.5
    _COOLDOWN = 60.0

    def __init__(self, clock=time.monotonic) -> None:
        self._clock = clock
        self._lock = threading.Lock()
        # (시각, 성공 여부). 창 밖으로 밀려나면 버린다.
        self._outcomes: deque[tuple[float, bool]] = deque()
        self._opened_at: float | None = None
        self._probe_in_flight = False

    def check(self) -> None:
        """호출해도 되는지. 열려 있으면 [CircuitOpen]을 던진다.

        열린 지 60초가 지났으면 **한 건만** 정찰로 통과시킨다. 정찰이
        끝나기 전의 다른 요청은 계속 막는다 — 회복 확인에 두 건이 필요한
        것은 아니다.
        """
        with self._lock:
            if self._opened_at is None:
                return
            now = self._clock()
            if now - self._opened_at < self._COOLDOWN:
                raise CircuitOpen()
            if self._probe_in_flight:
                raise CircuitOpen()
            self._probe_in_flight = True

    def record_success(self) -> None:
        with self._lock:
            if self._opened_at is not None:
                # 열려 있는데 성공이 왔다 — **정찰일 때만** 닫는다. 열리기
                # 전에 출발했던 낙오자의 뒤늦은 성공(4xx 포함)으로 닫으면,
                # 죽어 있는 벤더로 트래픽이 곧장 돌아간다. 낙오자가 정찰
                # 중에 완료돼 오인될 창은 몇 초뿐이다 — 호출 수명이 최대
                # 65초(연결 5+응답 60)로 냉각 60초와 거의 같아서다.
                if self._probe_in_flight:
                    self._opened_at = None
                    self._probe_in_flight = False
                    self._outcomes.clear()
                return
            self._outcomes.append((self._clock(), True))
            self._prune()

    def record_failure(self) -> None:
        with self._lock:
            now = self._clock()
            if self._opened_at is not None:
                # 정찰 실패면 다시 60초를 쉰다. 낙오자의 실패는 무시한다 —
                # 그때마다 냉각을 늘리면 60초 약속이 조용히 길어진다.
                if self._probe_in_flight:
                    self._opened_at = now
                    self._probe_in_flight = False
                return
            self._outcomes.append((now, False))
            self._prune()
            failures = sum(1 for _, ok in self._outcomes if not ok)
            total = len(self._outcomes)
            if total >= self._MIN_SAMPLES and failures / total > self._THRESHOLD:
                self._opened_at = now

    def would_block(self) -> bool:
        """지금 check()가 막을 것인지, 정찰 슬롯을 **집지 않고** 미리 본다.

        라우트가 호출 상한을 깎기 전에 쓴다. 브레이커 열림 503은 벤더를
        부르지 않아 비용이 없는데, 상한 한 칸을 태우면 벤더가 회복된 뒤
        정작 그 사용자가 429에 막힌다. check()를 그대로 쓰면 미리보기가
        정찰 슬롯을 집어 버려 진짜 호출이 자기 자신에게 막힌다.
        """
        with self._lock:
            if self._opened_at is None:
                return False
            if self._clock() - self._opened_at < self._COOLDOWN:
                return True
            return self._probe_in_flight

    def abandon_probe(self) -> None:
        """정찰이 벤더 생사와 무관한 예외로 끝났을 때 슬롯만 돌려준다.

        돌려주지 않으면 다음 check()가 영원히 CircuitOpen이다 — 벤더가
        돌아와도 서버를 재시작하기 전까지 막혀 있고, 사용자에게 나가는
        "1분 뒤 다시 시도해 주세요"가 거짓이 된다.
        """
        with self._lock:
            self._probe_in_flight = False

    def _prune(self) -> None:
        cutoff = self._clock() - self._WINDOW
        while self._outcomes and self._outcomes[0][0] <= cutoff:
            self._outcomes.popleft()


#: 상담·피부가 함께 쓰는 브레이커. 벤더가 하나이므로 창도 하나다.
breaker = CircuitBreaker()

@contextmanager
def guard():
    """벤더 호출 한 번을 감싼다: 확인 → 호출 → 분류·기록.

    확인·분류·기록을 호출자마다 따로 짜면 정책이 갈라진다 — 브레이커를
    공유하는 이유가 "한쪽의 관측이 다른 쪽에도 유효해서"인데, 분류가
    다르면 그 창이 섞인 잣대로 채워진다. 그래서 기제를 여기 한곳에 둔다.

    분류 밖 예외(SDK 검증 오류 등)는 벤더의 생사를 말해 주지 않으므로
    기록하지 않되, **정찰 슬롯은 반드시 돌려준다** — 놓치면 브레이커가
    영구히 잠긴다.
    """
    breaker.check()
    try:
        yield
    except (APIConnectionError, httpx.HTTPError):
        # 연결 실패·타임아웃 — 벤더가 살아 있다는 증거가 없다.
        # httpx 오류를 따로 받는 이유: SDK는 요청 전송 실패만
        # APIConnectionError로 감싸고, **스트리밍 본문을 읽는 중**의
        # ReadTimeout·RemoteProtocolError는 날것으로 던진다. 벤더가 연결은
        # 받고 중간에 침묵하는 가장 흔한 열화가 바로 이 모양인데, 이걸
        # 안 세면 브레이커는 정확히 필요한 순간에 열리지 않는다.
        breaker.record_failure()
        raise
    except APIStatusError as exc:
        # 5xx만 벤더 장애. 4xx는 벤더가 멀쩡히 응답한 것이다.
        if exc.status_code >= 500:
            breaker.record_failure()
        else:
            breaker.record_success()
        raise
    except BaseException:
        breaker.abandon_probe()
        raise
    else:
        breaker.record_success()


#: 브레이커가 열렸을 때 사용자에게 그대로 나가는 문구.
OPEN_MESSAGE = (
    "AI 응답이 계속 실패해 잠시 쉬어 가고 있습니다. 1분 뒤 다시 시도해 주세요."
)
