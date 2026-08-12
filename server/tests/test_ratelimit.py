"""요청 횟수 상한.

Claude 크레딧을 쓰는 엔드포인트라 상한이 실제로 막는지 확인합니다.
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.ratelimit import SlidingWindow  # noqa: E402


class TestSlidingWindow:
    def test_allows_up_to_the_limit(self):
        window = SlidingWindow(limit=3, window_seconds=60)
        assert [window.allow("u") for _ in range(3)] == [True, True, True]

    def test_blocks_past_the_limit(self):
        window = SlidingWindow(limit=2, window_seconds=60)
        window.allow("u")
        window.allow("u")
        assert window.allow("u") is False

    def test_counts_each_key_separately(self):
        # 한 사람이 상한에 걸렸다고 다른 사람까지 막히면 안 됩니다.
        window = SlidingWindow(limit=1, window_seconds=60)
        assert window.allow("a") is True
        assert window.allow("a") is False
        assert window.allow("b") is True

    def test_recovers_after_the_window_slides(self):
        window = SlidingWindow(limit=1, window_seconds=0.05)
        assert window.allow("u") is True
        assert window.allow("u") is False
        time.sleep(0.06)
        assert window.allow("u") is True

    def test_blocked_request_does_not_extend_the_wait(self):
        # 막힌 요청까지 세면, 계속 두드리는 사람은 영영 못 들어옵니다.
        window = SlidingWindow(limit=1, window_seconds=0.05)
        window.allow("u")
        for _ in range(5):
            assert window.allow("u") is False
        time.sleep(0.06)
        assert window.allow("u") is True

    def test_reports_when_to_retry(self):
        window = SlidingWindow(limit=1, window_seconds=60)
        window.allow("u")
        assert 0 < window.retry_after_seconds("u") <= 61

    def test_retry_after_is_zero_for_unseen_key(self):
        assert SlidingWindow(limit=1, window_seconds=60).retry_after_seconds("?") == 0

    def test_forgets_keys_that_stopped_calling(self):
        # 안 치우면 사용자 수만큼 메모리에 쌓입니다.
        window = SlidingWindow(limit=1, window_seconds=0.01)
        for i in range(1200):
            window.allow(f"u{i}")
        time.sleep(0.02)
        window.allow("last")
        assert len(window._hits) < 1200
