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
    unknown="사진으로는 가려운지 알 수 없어요.",
    advice="보습을 자주 해 주세요.",
)

#: 나이는 서버가 필수로 받습니다. 나이에 걸린 안전 조항이 여기 달려 있습니다.
FIELDS = {"age_months": "5"}


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
    monkeypatch.setattr(skin.model, "read", lambda image, media_type, age, fever: READING)


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
            skin.model, "read", lambda image, media_type, age, fever: calls.append(1) or READING
        )
        client.post("/api/skin/diagnose", files=photo())
        assert calls == []


class TestFileShape:
    """모델을 부르기 전에 걸러야 하는 것들. 부르고 나면 이미 돈이 나갑니다."""

    def test_rejects_an_empty_file(self, logged_in, reads):
        response = client.post(
            "/api/skin/diagnose", files={"file": ("x.jpg", b"", "image/jpeg")},
            data=FIELDS,
            headers=AUTHED,
        )
        assert response.status_code == 400

    def test_rejects_a_file_that_is_not_an_image(self, logged_in, reads):
        # 확장자와 Content-Type은 보내는 쪽이 마음대로 적을 수 있습니다.
        response = client.post(
            "/api/skin/diagnose",
            files={"file": ("skin.jpg", b"not an image at all", "image/jpeg")},
            data=FIELDS,
            headers=AUTHED,
        )
        assert response.status_code == 400

    def test_does_not_call_claude_for_a_non_image(self, logged_in, monkeypatch):
        calls = []
        monkeypatch.setattr(
            skin.model, "read", lambda image, media_type, age, fever: calls.append(1) or READING
        )
        client.post(
            "/api/skin/diagnose",
            files={"file": ("skin.jpg", b"%PDF-1.4 fake", "image/jpeg")},
            data=FIELDS,
            headers=AUTHED,
        )
        assert calls == []

    def test_rejects_too_large_a_photo(self, logged_in, reads, monkeypatch):
        monkeypatch.setattr(main.settings, "max_upload_bytes", 128)
        response = client.post(
            "/api/skin/diagnose", files=photo(JPEG + b"\x00" * 500), data=FIELDS, headers=AUTHED
        )
        assert response.status_code == 413

    def test_accepts_png(self, logged_in, reads):
        response = client.post(
            "/api/skin/diagnose",
            files={"file": ("skin.png", PNG, "image/png")},
            data=FIELDS,
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
        body = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED).json()
        assert body["status"] == "success"
        assert body["level"] == "caution"
        assert body["urgent"] is False
        assert body["advice"] == "보습을 자주 해 주세요."

    def test_server_attaches_the_disclaimer(self, logged_in, reads):
        body = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED).json()
        assert body["disclaimer"] == advice.DISCLAIMER

    def test_never_returns_a_diagnosis_name(self, logged_in, reads):
        """진단명은 응답 어디에도 없어야 합니다.

        앱 전체가 병명을 말하지 않기로 했습니다(advice.py의 SYSTEM_PROMPT).
        예전 이 화면만 '진단 결과: 흑색종 (88.4%)'을 띄웠습니다.
        """
        body = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED).json()
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
            lambda image, media_type, age, fever: skin.SkinReading(
                is_skin=False,
                level="normal",
                urgent=False,
                observations=[],
                unknown="",
                advice="사진이 어두워 잘 보이지 않습니다. 밝은 곳에서 다시 찍어 주세요.",
            ),
        )
        body = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED).json()
        assert body["status"] == "unreadable"
        assert "level" not in body

    def test_reports_an_urgent_reading(self, logged_in, monkeypatch):
        monkeypatch.setattr(
            skin.model,
            "read",
            lambda image, media_type, age, fever: READING._replace(level="consult", urgent=True),
        )
        body = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED).json()
        assert body["urgent"] is True

    def test_turns_a_failure_into_korean(self, logged_in, monkeypatch):
        # 예전에는 f"...: {exc}"로 예외를 그대로 내보내 영문 원문이 화면에
        # 그대로 떴습니다.
        def boom(image, media_type, age, fever):
            raise RuntimeError("Connection reset by peer")

        monkeypatch.setattr(skin.model, "read", boom)
        response = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED)
        assert response.status_code == 500
        assert "Connection reset" not in response.json()["detail"]


class TestSafetyFloor:
    """모델이 낸 값을 코드가 한 번 더 잠급니다. **내리지 않고 올리기만.**

    구조화 출력은 **모양만** 보장합니다. 스키마를 100% 통과하면서도
    앞뒤가 안 맞는 값이 나올 수 있습니다.
    """

    def test_urgent_pulls_the_level_up(self):
        # {"level":"caution","urgent":true}는 스키마를 통과하는데, 앱은 색을
        # level로 그리므로 급한 결과가 덜 급한 색으로 나갑니다.
        assert skin._settle(
            level="caution", urgent=True, age_months=5, has_fever="no"
        ) == ("consult", True)

    def test_fever_pulls_the_level_up(self):
        # 열은 사진에 없습니다. 이 판단만은 모델이 아니라 코드가 합니다.
        assert skin._settle(
            level="caution", urgent=False, age_months=8, has_fever="yes"
        ) == ("consult", False)

    def test_fever_under_three_months_is_urgent(self):
        # advice.py의 응급 목록 맨 위에 있는 항목입니다.
        assert skin._settle(
            level="caution", urgent=False, age_months=2, has_fever="yes"
        ) == ("consult", True)

    def test_unknown_fever_is_not_treated_as_none(self):
        # 재보지 않은 것과 열이 없는 것은 다른 말입니다.
        assert skin._settle(
            level="caution", urgent=False, age_months=2, has_fever="unknown"
        ) == ("caution", False)

    def test_never_pulls_the_level_down(self):
        assert skin._settle(
            level="consult", urgent=False, age_months=20, has_fever="no"
        ) == ("consult", False)

    def test_normal_is_not_a_level(self):
        """'정상'은 안심이 아니라 반대 방향의 진단입니다.

        체온은 공인 임계값이 있어 정상을 말할 수 있지만, 사진 한 장에는
        정상의 근거가 없습니다.
        """
        assert skin.RESPONSE_SCHEMA["properties"]["level"]["enum"] == [
            "caution",
            "consult",
        ]

    def test_unknown_is_required(self):
        # 한 덩어리 글로 받으면 "모른다"가 가장 먼저 빠지는 문장입니다.
        assert "unknown" in skin.RESPONSE_SCHEMA["required"]


class TestContext:
    """나이와 열은 사진에 없습니다. 앱이 실어 보냅니다."""

    def test_age_is_required(self, logged_in, reads):
        # 선택으로 두면 앱이 안 보내도 200이 나가고, 나이에 걸린 안전 조항이
        # 조용히 죽은 채로 서비스가 돕니다.
        response = client.post(
            "/api/skin/diagnose", files=photo(), headers=AUTHED
        )
        assert response.status_code == 422

    def test_fever_defaults_to_unknown(self, logged_in, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            skin.model,
            "read",
            lambda image, media_type, age, fever: seen.update(fever=fever) or READING,
        )
        client.post(
            "/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED
        )
        assert seen["fever"] == "unknown"

    def test_rejects_a_nonsense_fever_value(self, logged_in, reads):
        response = client.post(
            "/api/skin/diagnose",
            files=photo(),
            data={**FIELDS, "has_fever": "아마도"},
            headers=AUTHED,
        )
        assert response.status_code == 422

    def test_passes_age_and_fever_through(self, logged_in, monkeypatch):
        seen = {}
        monkeypatch.setattr(
            skin.model,
            "read",
            lambda image, media_type, age, fever: seen.update(age=age, fever=fever)
            or READING,
        )
        client.post(
            "/api/skin/diagnose",
            files=photo(),
            data={"age_months": "2", "has_fever": "yes"},
            headers=AUTHED,
        )
        assert seen == {"age": 2, "fever": "yes"}


class TestPromptHasNoCancerCriteria:
    """암을 안 다루기로 해 놓고 암 판별 기준을 남겨 두면 안 됩니다.

    한때 프롬프트에 "검거나 짙게 변한 점, 모양이 고르지 않은 점"과
    "상처가 아물지 않고 남아 있는 것"이 있었습니다. 각각 흑색종 ABCDE와
    비치유성 병변 기준으로, 폐기한 성인 데이터셋의 임상 로직이 단어만 빠진
    채 돌아와 있던 것입니다. 스무 줄 위에는 "암은 다루지 않습니다"가
    적혀 있었습니다.
    """

    def test_no_melanoma_abcde(self):
        for phrase in ["모양이 고르지 않은", "짙게 변한 점", "색이 고르지 않"]:
            assert phrase not in skin.SYSTEM_PROMPT, phrase

    def test_no_non_healing_lesion(self):
        assert "아물지 않" not in skin.SYSTEM_PROMPT

    def test_no_cancer_names(self):
        # 금지어를 적는 것 자체가 그 단어를 프롬프트 안으로 들여오는 일입니다.
        for name in ["흑색종", "편평세포암", "광선각화증"]:
            assert name not in skin.SYSTEM_PROMPT, name

    def test_urgency_is_not_measured_by_area(self):
        # 신생아의 물집 두세 개는 "넓게" 번진 것이 아닙니다.
        assert "넓이로 재지 마세요" in skin.SYSTEM_PROMPT


class TestCommonAreas:
    """보호자가 실제로 사진을 찍는 자리를 프롬프트가 다루는가.

    폐기한 성인 데이터셋에는 기저귀 발진·땀띠·태열이 **라벨조차 없었습니다**.
    그 자리들이야말로 이 앱에 사진이 올라오는 이유인데, 프롬프트에도 한 줄도
    없었습니다. 무엇을 볼지 짚어 주지 않으면 관찰이 "붉은 기가 보입니다"에서
    멈추고, 그것으로는 진료실에서 할 말이 늘지 않습니다.

    **힌트를 주되 병명은 들이지 않는다**가 이 절의 조건입니다.
    """

    def _section(self):
        s = skin.SYSTEM_PROMPT
        start = s.index("## 보호자가 자주 찍는 자리")
        return s[start:s.index("## 사진으로 알 수 있는", start)]

    def test_covers_the_places_parents_photograph(self):
        section = self._section()
        for place in ["기저귀", "사타구니", "접히는 곳", "겨드랑이", "얼굴과 머리"]:
            assert place in section, place

    def test_says_what_to_look_at_and_what_to_do(self):
        section = self._section()
        assert section.count("볼 것:") == 3
        assert section.count("할 수 있는 것:") == 3

    def test_brings_no_disease_names(self):
        """힌트가 병명을 뒷문으로 들여오면 안 됩니다.

        '주름 안쪽까지 들어갔는지'는 보이는 것이고, '칸디다'는 진단입니다.
        전자만 씁니다.
        """
        section = self._section()
        for name in ["아토피", "지루", "칸디다", "땀띠", "태열", "습진",
                     "피부염", "진균", "곰팡이"]:
            assert name not in section, name

    def test_forbids_interpreting_the_hints(self):
        # 볼 것을 짚어 주면 모델이 그것으로 병을 가리려 합니다.
        section = self._section()
        assert "이것으로 병을 가리려 하지 마세요" in section
        assert "그것이 무엇을 뜻하는지는 쓰지 마세요" in section

    def test_care_advice_names_no_product(self):
        """'할 수 있는 것'이 약·연고·제품 이름으로 새지 않는지.

        앱 전체가 약 이름을 말하지 않기로 했습니다. 기저귀 자리에서 특히
        새기 쉬운 자리라 여기서 한 번 더 봅니다.
        """
        section = self._section()
        for word in ["크림", "연고", "파우더", "베이비파우더", "스테로이드", "제품"]:
            assert word not in section, word

    def test_does_not_apply_advice_everywhere(self):
        # 얼굴 사진에 "기저귀를 자주 갈아 주세요"가 붙으면 안 됩니다.
        section = self._section()
        assert "그 자리로 보일 때만" in section


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
                "/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED
            ).status_code == 200

        blocked = client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED)
        assert blocked.status_code == 429
        assert "Retry-After" in blocked.headers

    def test_does_not_call_claude_when_blocked(self, logged_in, monkeypatch):
        calls = []
        monkeypatch.setattr(
            skin.model, "read", lambda image, media_type, age, fever: calls.append(1) or READING
        )
        monkeypatch.setattr(main._skin_per_user_limit, "_limit", 1)

        client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED)
        client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED)
        assert len(calls) == 1

    def test_global_limit_catches_many_accounts(self, reads, monkeypatch):
        monkeypatch.setattr(main._skin_global_limit, "_limit", 3)

        for i in range(3):
            main.app.dependency_overrides[auth.require_user] = lambda i=i: f"user-{i}"
            assert client.post(
                "/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED
            ).status_code == 200

        main.app.dependency_overrides[auth.require_user] = lambda: "user-new"
        assert client.post(
            "/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED
        ).status_code == 429

    def test_photos_do_not_eat_the_advice_budget(
        self, logged_in, reads, monkeypatch
    ):
        """사진을 상한까지 보내도 상담은 그대로 열려 있어야 합니다."""
        monkeypatch.setattr(main._skin_per_user_limit, "_limit", 1)
        monkeypatch.setattr(
            advice.client, "ask", lambda **kw: advice.Answer("네", False)
        )

        client.post("/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED)
        assert client.post(
            "/api/skin/diagnose", files=photo(), data=FIELDS, headers=AUTHED
        ).status_code == 429

        answer = client.post(
            "/api/advice",
            json={"messages": [{"role": "user", "content": "열이 나요"}]},
            headers=AUTHED,
        )
        assert answer.status_code == 200
