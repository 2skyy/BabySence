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
      // 낮은 쪽으로 떨어뜨리면 서버가 무엇을 보냈든 화면이 '정상'이 됩니다.
      expect(
        service.contains('default:\n        return AssessmentLevel.consult;'),
        isTrue,
      );
    });
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
