"""요청 횟수 상한.

로그인만으로는 총액이 막히지 않습니다. 계정 하나로도 스크립트를 돌리면
크레딧이 빠르게 녹고, 계정은 얼마든지 새로 만들 수 있습니다. 그래서
사용자별 상한과 서버 전체 상한을 함께 둡니다.

**한 프로세스 안에서만 셉니다.** 서버를 여러 대로 늘리거나 워커를 여러 개
띄우면 각자 따로 세므로 실제 상한은 그 배수가 됩니다. 지금은 한 대로
돌리고 있어 충분하고, 늘릴 때는 Redis 같은 공용 저장소가 필요합니다.
"""

import time
from collections import deque


class SlidingWindow:
    """미끄러지는 창으로 셉니다.

    매시 정각에 초기화되는 고정 창은 경계에서 두 배가 통과합니다 —
    12:59에 30번, 13:00에 또 30번. 창을 미끄러뜨리면 그 구멍이 없습니다.
    """

    def __init__(self, limit: int, window_seconds: int) -> None:
        self._limit = limit
        self._window = window_seconds
        self._hits: dict[str, deque[float]] = {}

    def allow(self, key: str) -> bool:
        """한 번 세고, 상한을 넘지 않았으면 True."""
        now = time.monotonic()
        cutoff = now - self._window

        hits = self._hits.setdefault(key, deque())
        while hits and hits[0] <= cutoff:
            hits.popleft()

        if len(hits) >= self._limit:
            return False

        hits.append(now)
        self._sweep(cutoff)
        return True

    def retry_after_seconds(self, key: str) -> int:
        """가장 오래된 기록이 창을 빠져나갈 때까지 남은 시간."""
        hits = self._hits.get(key)
        if not hits:
            return 0
        return max(1, int(hits[0] + self._window - time.monotonic()) + 1)

    def _sweep(self, cutoff: float) -> None:
        """오래 안 쓰인 키를 치웁니다. 안 그러면 사용자 수만큼 쌓입니다."""
        if len(self._hits) <= 1000:
            return
        for key in [k for k, v in self._hits.items() if not v or v[-1] <= cutoff]:
            del self._hits[key]
