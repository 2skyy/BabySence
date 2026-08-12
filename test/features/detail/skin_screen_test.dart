import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 피부 화면은 오래 **진단하는 화면**이었습니다.
///
/// 성인 피부암 데이터셋(ISIC 계열 9종)으로 만들 예정이던 분류기 자리에
/// 늘 같은 값을 돌려주는 껍데기가 있었고, 화면은 그것을
/// "진단 결과: 흑색종 (88.4%)"처럼 띄웠습니다. 영유아에게는 거의 없는
/// 질환들이라 기저귀 발진 사진에 암 이름이 붙을 수 있었습니다.
///
/// 화면 코드는 위젯 테스트가 없어, 되돌아가는 것을 글자로 막습니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// 주석을 뺀 본문. 무엇을 지웠는지 적어 둔 설명까지 걸리면, 되돌아가지
  /// 않으려고 남긴 기록이 오히려 테스트를 깨뜨립니다.
  String code(String path) => read(path)
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  final page = code('lib/features/detail/skin_analysis_page.dart');
  final service = read('lib/features/detail/skin/skin_service.dart');
  final serverPrompt = read('server/app/skin.py');

  group('암은 다루지 않는다', () {
    const cancerWords = [
      '흑색종',
      'Melanoma',
      '편평세포암',
      'Squamous carcinoma',
      '광선각화증',
      'Actinic keratosis',
      '피부섬유종',
      'Dermatofibroma',
    ];

    for (final word in cancerWords) {
      test('화면에 "$word"이(가) 없다', () {
        expect(page.contains(word), isFalse,
            reason: '영유아 앱에서 보호자에게 내보낼 말이 아닙니다');
      });
    }

    test('서버 지침이 암을 금지한다', () {
      expect(serverPrompt.contains('암은 다루지 않습니다'), isTrue);
    });
  });

  group('진단하지 않는다', () {
    test('화면이 진단명·확률을 그리지 않는다', () {
      expect(page.contains('진단 결과'), isFalse);
      expect(page.contains('_koDiseases'), isFalse,
          reason: '병명 대응표 자체를 두지 않습니다');
      expect(page.contains('probability'), isFalse);
    });

    test('서버 스키마에 진단명 칸이 없다', () {
      // 칸을 두면 모델이 채우려 듭니다.
      expect(serverPrompt.contains('"disease"'), isFalse);
      expect(serverPrompt.contains('"probability"'), isFalse);
    });

    test('앱이 받는 결과에도 병명이 없다', () {
      expect(service.contains('disease'), isFalse);
    });
  });

  group('조용히 실패하지 않는다', () {
    test('사진 선택 실패를 화면에 말한다', () {
      // 예전에는 debugPrint만 하고 넘어가, 권한을 거부한 사용자에게는
      // 아무 일도 일어나지 않는 것처럼 보였습니다.
      expect(page.contains('카메라 권한을 확인해 주세요'), isTrue);
      expect(page.contains('사진 접근 권한을 확인해 주세요'), isTrue);
    });

    test('서버 오류를 한국어로 바꾼다', () {
      // 예전에는 "서버 연동 실패: $e"로 DioException 원문이 그대로 떴습니다.
      expect(page.contains(r'서버 연동 실패: $e'), isFalse);
      expect(service.contains('_messageFor(DioException e)'), isTrue);
    });

    test('판독 실패를 정상과 구별한다', () {
      // 확인이 안 됐다는 것과 괜찮다는 것은 다른 말입니다.
      expect(service.contains('class SkinUnreadable'), isTrue);
      expect(page.contains('on SkinUnreadable'), isTrue);
    });

    test('모르는 단계는 높은 쪽으로 붙인다', () {
      // 낮은 쪽으로 떨어뜨리면 서버가 무엇을 보냈든 화면이 덜 급해집니다.
      expect(
        service.contains('default:\n        return AssessmentLevel.consult;'),
        isTrue,
      );
    });
  });

  group("'정상'이라고 말하지 않는다", () {
    // 사진 한 장으로 괜찮다고 하는 것은 안심이 아니라 **반대 방향의
    // 진단**입니다. 체온은 공인 임계값이 있어 정상을 말할 수 있지만
    // 사진에는 그 근거가 없습니다. 초록을 본 보호자는 그 화면을 근거로
    // 자기 판단을 멈춥니다.

    test('normal을 단계로 받지 않는다', () {
      expect(service.contains("case 'normal':"), isFalse);
    });

    test('결과 카드에 초록이 없다', () {
      final card = page.substring(page.indexOf('class _ReadingCard'));
      expect(card.contains('Colors.green'), isFalse);
    });

    test('판정 화면의 단계 이름을 그대로 쓰지 않는다', () {
      // '주의'·'상담 권장'은 공인 임계값으로 계산한 판정의 이름입니다.
      // 사진은 판정이 아니라 관찰이라 판정처럼 보이면 안 됩니다.
      expect(page.contains('reading.level.label'), isFalse);
      expect(page.contains('급해 보이는 신호가 보이지 않습니다'), isTrue);
    });
  });

  group('사진에 없는 것을 채워 넣는다', () {
    test('개월 수를 함께 보낸다', () {
      // 나이에 걸린 안전 조항(3개월 미만 발열, 아주 어린 아기의 물집)이
      // 여기 달려 있습니다.
      expect(service.contains("'age_months': ageInMonths"), isTrue);
      expect(page.contains('ageInMonthsAt(baby.birthDate'), isTrue);
    });

    test('아이를 못 읽으면 보내지 않는다', () {
      expect(page.contains('아이 정보를 불러오지 못했습니다'), isTrue);
    });

    test('열은 세 값이다', () {
      // 예/아니요 둘이면 "재보지 않았음"이 "아니요"로 접힙니다.
      expect(page.contains("return 'unknown';"), isTrue);
      expect(page.contains("return feverish ? 'yes' : 'no';"), isTrue);
    });

    test('체온 조회가 실패해도 없음으로 접지 않는다', () {
      final fever = page.substring(
        page.indexOf('static Future<String> _recentFever'),
        page.indexOf('Future<void> _analyze'),
      );
      // 이 함수가 돌려줄 수 있는 값 중 catch에서 나오는 것은 unknown뿐이어야
      // 합니다. 'no'로 접으면 못 잰 아이가 열이 없는 아이가 됩니다.
      expect(fever.contains("catch (_)"), isTrue);
      expect(fever.lastIndexOf("return 'unknown';") > fever.indexOf("catch (_)"),
          isTrue);
    });
  });

  group('알 수 없는 것을 밝힌다', () {
    test('unknown을 받아 화면에 그린다', () {
      expect(service.contains('final String unknown'), isTrue);
      expect(page.contains('reading.unknown'), isTrue);
    });

    test('결과 카드가 진단이 아님을 적는다', () {
      expect(page.contains('이 안내는 진단이 아닙니다'), isTrue);
    });

    test('사진과 무관한 응급 안내가 늘 있다', () {
      expect(page.contains('_EmergencyNotice'), isTrue);
      expect(page.contains('사진과 관계없이 지금 바로 진료를 받아 주세요'), isTrue);
    });

    test('판독 실패가 안심으로 읽히지 않게 한다', () {
      // 새벽에 어두운 방에서 찍은 사진이 예외가 아니라 표준입니다.
      expect(page.contains('확인하지 못했다는 것은 괜찮다는 뜻이 아닙니다'), isTrue);
    });
  });

  test('약 이름·용량이 상담 맥락으로 나가지 않는다', () {
    // 이름과 용량은 보호자가 직접 적는 자유 입력이고, 맥락에는 "답변할 때
    // 참고하세요"가 붙습니다. 모델에게는 약 이름을 말하지 말라고 해 두었는데
    // 그 값이 바로 옆에 놓여 있으면 되짚는 순간 금지한 것이 나갑니다.
    // 병원 방문은 원래부터 라벨만 보내고 있었습니다.
    final context = code('lib/features/advice/chat_context.dart');
    expect(context.contains('m.summary'), isFalse,
        reason: 'summary는 name과 dose를 담습니다');
    expect(context.contains(r'약 ${m.reason.label}'), isTrue);
  });

  group('크레딧을 지킨다', () {
    final server = read('server/app/main.py');

    test('로그인해야 부를 수 있다', () {
      // 이 엔드포인트는 오래 열려 있었습니다. 그때는 고정값을 돌려주는
      // 자리라 크레딧이 나가지 않았기 때문입니다.
      final endpoint = server.substring(server.indexOf('async def diagnose_skin'));
      expect(endpoint.contains('Depends(auth.require_user)'), isTrue);
    });

    test('앱이 토큰을 싣는다', () {
      expect(service.contains("'Authorization': 'Bearer \$token'"), isTrue);
    });

    test('상담과 상한 통이 다르다', () {
      // 사진 한 장은 글자 질문보다 토큰을 훨씬 많이 먹습니다. 둘은 같은
      // API 키, 곧 같은 지갑을 씁니다.
      expect(server.contains('_skin_per_user_limit'), isTrue);
      expect(server.contains('_skin_global_limit'), isTrue);
    });

    test('사진을 줄여서 보낸다', () {
      // 요즘 휴대폰 사진은 5MB를 넘는데 서버는 4MB까지만 받습니다.
      expect(page.contains('maxWidth: 1568'), isTrue);
      expect(page.contains('imageQuality: 85'), isTrue);
    });
  });
}
