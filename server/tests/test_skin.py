"""/api/skin/diagnose 엔드포인트.

Claude를 부르지 않습니다. 확인하는 것은 **모델에 닿기 전에 무엇이 걸러지는가**,
그리고 **모델이 낸 값이 화면까지 어떤 모양으로 나가는가**입니다.

이 엔드포인트는 오래 열려 있었습니다. 그때는 고정값을 돌려주는 자리라
크레딧이 나가지 않았기 때문입니다. 이제 사진 한 장마다 Claude를 부르고,
상담과 **같은 API 키 = 같은 크레딧**을 씁니다.
"""

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import advice, auth, main, skin  # noqa: E402

client = TestClient(main.app)

AUTHED = {"Authorization": "Bearer token"}

#: 가장 작은 유효 JPEG 머리. 매직 바이트만 맞으면 됩니다 — 서버는 픽셀을
#: 열어 보지 않고 Claude에 그대로 넘깁니다.
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 64
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


def photo(data: bytes = JPEG, name: str = "skin.jpg"):
    return {"file": (name, data, "image/jpeg")}


READING = skin.SkinReading(
    is_skin=True,
    level="caution",
    urgent=False,
    observations=["볼 주변에 붉은 기가 보입니다."],
    advice="보습을 자주 해 주세요.",
)


@pytest.fixture(autouse=True)
def clean_state():
    main._skin_per_user_limit._hits.clear()
    main._skin_global_limit._hits.clear()
    main._per_user_limit._hits.clear()
    main._global_limit._hits.clear()
    main.app.dependency_overrides.clear()
    yield
    main.app.dependency_overrides.clear()


@pytest.fixture
def logged_in():
    main.app.dependency_overrides[auth.require_user] = lambda: "user-1"


@pytest.fixture
def reads(monkeypatch):
    """Claude 대신 고정 결과를 돌려줍니다."""
    monkeypatch.setattr(skin.model, "read", lambda image, media_type: READING)


class TestAuthRequired:
    """크레딧을 쓰는 엔드포인트라 로그인 없이는 닿지 않아야 합니다."""

    def test_rejects_anonymous(self):
        assert client.post("/api/skin/diagnose", files=photo()).status_code == 401

    def test_rejects_wrong_scheme(self):
        response = client.post(
            "/api/skin/diagnose",
            files=photo(),
            headers={"Authorization": "Basic xyz"},
        )
        assert response.status_code == 401

    def test_does_not_call_claude_when_anonymous(self, monkeypatch):
        calls = []
        monkeypatch.setattr(
            skin.model, "read", lambda image, media_type: calls.append(1) or READING
        )
        client.post("/api/skin/diagnose", files=photo())
        assert calls == []


class TestFileShape:
    """모델을 부르기 전에 걸러야 하는 것들. 부르고 나면 이미 돈이 나갑니다."""

    def test_rejects_an_empty_file(self, logged_in, reads):
        response = client.post(
            "/api/skin/diagnose", files={"file": ("x.jpg", b"", "image/jpeg")},
            headers=AUTHED,
        )
        assert response.status_code == 400

    def test_rejects_a_file_that_is_not_an_image(self, logged_in, reads):
        # 확장자와 Content-Type은 보내는 쪽이 마음대로 적을 수 있습니다.
        response = client.post(
            "/api/skin/diagnose",
            files={"file": ("skin.jpg", b"not an image at all", "image/jpeg")},
            headers=AUTHED,
        )
        assert response.status_code == 400

    def test_does_not_call_claude_for_a_non_image(self, logged_in, monkeypatch):
        calls = []
        monkeypatch.setattr(
            skin.model, "read", lambda image, media_type: calls.append(1) or READING
        )
        client.post(
            "/api/skin/diagnose",
            files={"file": ("skin.jpg", b"%PDF-1.4 fake", "image/jpeg")},
            headers=AUTHED,
        )
        assert calls == []

    def test_rejects_too_large_a_photo(self, logged_in, reads, monkeypatch):
        monkeypatch.setattr(main.settings, "max_upload_bytes", 128)
        response = client.post(
            "/api/skin/diagnose", files=photo(JPEG + b"\x00" * 500), headers=AUTHED
        )
        assert response.status_code == 413

    def test_accepts_png(self, logged_in, reads):
        response = client.post(
            "/api/skin/diagnose",
            files={"file": ("skin.png", PNG, "image/png")},
            headers=AUTHED,
        )
        assert response.status_code == 200


class TestMediaTypeDetection:
    """Content-Type이 아니라 파일 앞부분을 봅니다.

    형식을 틀리게 넘기면 Anthropic이 영문 400을 내는데, 그 문구가 그대로
    보호자 화면에 뜹니다.
    """

    def test_reads_the_real_format_not_the_header(self):
        assert skin.detect_media_type(PNG) == "image/png"
        assert skin.detect_media_type(JPEG) == "image/jpeg"

    def test_webp_needs_more_than_the_first_four_bytes(self):
        # RIFF만 보면 wav 파일도 통과합니다.
        assert skin.detect_media_type(b"RIFF\x00\x00\x00\x00WEBPVP8 ") == "image/webp"
        assert skin.detect_media_type(b"RIFF\x00\x00\x00\x00WAVEfmt ") is None

    def test_unknown_bytes_are_not_guessed(self):
        assert skin.detect_media_type(b"hello") is None
        assert skin.detect_media_type(b"") is None


class TestResult:
    def test_returns_the_reading(self, logged_in, reads):
        body = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED).json()
        assert body["status"] == "success"
        assert body["level"] == "caution"
        assert body["urgent"] is False
        assert body["advice"] == "보습을 자주 해 주세요."

    def test_server_attaches_the_disclaimer(self, logged_in, reads):
        body = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED).json()
        assert body["disclaimer"] == advice.DISCLAIMER

    def test_never_returns_a_diagnosis_name(self, logged_in, reads):
        """진단명은 응답 어디에도 없어야 합니다.

        앱 전체가 병명을 말하지 않기로 했습니다(advice.py의 SYSTEM_PROMPT).
        예전 이 화면만 '진단 결과: 흑색종 (88.4%)'을 띄웠습니다.
        """
        body = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED).json()
        assert "disease" not in body
        assert "probability" not in body

    def test_an_unreadable_photo_is_not_reported_as_normal(self, logged_in, monkeypatch):
        """피부가 아니거나 판독이 안 되는 사진.

        단계를 함께 내보내면 화면이 '정상'으로 그립니다. **확인이 안 됐다는
        것과 정상은 다른 말입니다.**
        """
        monkeypatch.setattr(
            skin.model,
            "read",
            lambda image, media_type: skin.SkinReading(
                is_skin=False,
                level="normal",
                urgent=False,
                observations=[],
                advice="사진이 어두워 잘 보이지 않습니다. 밝은 곳에서 다시 찍어 주세요.",
            ),
        )
        body = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED).json()
        assert body["status"] == "unreadable"
        assert "level" not in body

    def test_reports_an_urgent_reading(self, logged_in, monkeypatch):
        monkeypatch.setattr(
            skin.model,
            "read",
            lambda image, media_type: READING._replace(level="consult", urgent=True),
        )
        body = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED).json()
        assert body["urgent"] is True

    def test_turns_a_failure_into_korean(self, logged_in, monkeypatch):
        # 예전에는 f"...: {exc}"로 예외를 그대로 내보내 영문 원문이 화면에
        # 그대로 떴습니다.
        def boom(image, media_type):
            raise RuntimeError("Connection reset by peer")

        monkeypatch.setattr(skin.model, "read", boom)
        response = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED)
        assert response.status_code == 500
        assert "Connection reset" not in response.json()["detail"]


class TestRateLimit:
    """상담과 **통을 따로** 씁니다.

    사진 한 장은 글자 질문보다 토큰을 훨씬 많이 먹습니다. 같은 통에 넣으면
    사진 몇 장에 상담이 막히고, 반대로 상담에 맞춰 넉넉히 열면 사진 쪽이
    크레딧을 다 태웁니다. 둘은 같은 API 키를 씁니다.
    """

    def test_blocks_a_user_past_the_limit(self, logged_in, reads, monkeypatch):
        monkeypatch.setattr(main._skin_per_user_limit, "_limit", 2)

        for _ in range(2):
            assert client.post(
                "/api/skin/diagnose", files=photo(), headers=AUTHED
            ).status_code == 200

        blocked = client.post("/api/skin/diagnose", files=photo(), headers=AUTHED)
        assert blocked.status_code == 429
        assert "Retry-After" in blocked.headers

    def test_does_not_call_claude_when_blocked(self, logged_in, monkeypatch):
        calls = []
        monkeypatch.setattr(
            skin.model, "read", lambda image, media_type: calls.append(1) or READING
        )
        monkeypatch.setattr(main._skin_per_user_limit, "_limit", 1)

        client.post("/api/skin/diagnose", files=photo(), headers=AUTHED)
        client.post("/api/skin/diagnose", files=photo(), headers=AUTHED)
        assert len(calls) == 1

    def test_global_limit_catches_many_accounts(self, reads, monkeypatch):
        monkeypatch.setattr(main._skin_global_limit, "_limit", 3)

        for i in range(3):
            main.app.dependency_overrides[auth.require_user] = lambda i=i: f"user-{i}"
            assert client.post(
                "/api/skin/diagnose", files=photo(), headers=AUTHED
            ).status_code == 200

        main.app.dependency_overrides[auth.require_user] = lambda: "user-new"
        assert client.post(
            "/api/skin/diagnose", files=photo(), headers=AUTHED
        ).status_code == 429

    def test_photos_do_not_eat_the_advice_budget(
        self, logged_in, reads, monkeypatch
    ):
        """사진을 상한까지 보내도 상담은 그대로 열려 있어야 합니다."""
        monkeypatch.setattr(main._skin_per_user_limit, "_limit", 1)
        monkeypatch.setattr(
            advice.client, "ask", lambda **kw: advice.Answer("네", False)
        )

        client.post("/api/skin/diagnose", files=photo(), headers=AUTHED)
        assert client.post(
            "/api/skin/diagnose", files=photo(), headers=AUTHED
        ).status_code == 429

        answer = client.post(
            "/api/advice",
            json={"messages": [{"role": "user", "content": "열이 나요"}]},
            headers=AUTHED,
        )
        assert answer.status_code == 200
