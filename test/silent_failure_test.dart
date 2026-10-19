import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 이 프로젝트의 원칙 하나: **조회 실패와 "기록 없음"을 같은 말로 보여주지
/// 않는다.**
///
/// 한때 다섯 화면이 이걸 어겼습니다. 예외를 `debugPrint`만 하고 넘어가서,
/// 사용자에게는 "기록이 없다"로 보였습니다. 특히 홈에서는 그 null이
/// 수유 알림 예약을 **취소**하기까지 했습니다.
///
/// 화면 코드는 위젯 테스트가 없는 곳이 많아, 되돌아가는 것을 글자로 막습니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('실패를 삼키지 않는다', () {
    const screens = {
      'lib/features/home/home_page.dart': '_todayFailed',
      'lib/features/mypage/mypage_page.dart': '_loadFailed',
      'lib/features/mypage/co_parenting_page.dart': '_loadFailed',
      'lib/features/advice/chat_page.dart': '_contextFailed',
      'lib/features/detail/vaccination_page.dart': '_readinessFailed',
    };

    screens.forEach((path, flag) {
      test('${path.split('/').last} 에 실패 상태가 있다', () {
        expect(read(path).contains(flag), isTrue,
            reason: '$flag 를 두어 "못 읽음"과 "없음"을 구별하세요');
      });
    });

    test('홈 타일이 세 상태를 구별한다', () {
      final source = read('lib/features/home/home_page.dart');
      expect(source.contains("'불러오는 중…'"), isTrue);
      expect(source.contains("'불러오지 못함'"), isTrue);
      expect(source.contains("'기록 없음'"), isTrue);
    });
  });

  group('수유 알림', () {
    test('모르는 상태에서는 예약을 건드리지 않는다', () {
      // reschedule은 cancel부터 하고 nextAt이 null이면 그대로 끝냅니다.
      // 조회 실패로 lastFedAt이 null이면 예약이 조용히 사라집니다.
      final card =
          read('lib/features/feeding_reminder/next_feeding_card.dart');
      expect(card.contains('_rescheduleIfKnown'), isTrue);
      expect(card.contains('if (widget.loading || widget.failed) return;'), isTrue,
          reason: '로딩·실패 중에는 재예약을 부르지 않아야 합니다');
    });

    test('홈이 실패 여부를 카드에 넘긴다', () {
      expect(read('lib/features/home/home_page.dart').contains('failed: _todayFailed'),
          isTrue);
    });
  });

  test('상담 맥락이 실패해도 판정은 남긴다', () {
    // 판정은 화면이 이미 들고 있는 값이라 조회와 무관합니다. 함께 버리면
    // 판정에서 넘어온 대화인데 그 판정을 모른 채 답하게 됩니다.
    final source = read('lib/features/advice/chat_context.dart');
    expect(source.contains('addAssessment'), isTrue);
    // 실패 경로가 빈 문자열을 그대로 돌려주지 않아야 합니다.
    expect(source.contains("      return '';"), isFalse,
        reason: '실패해도 판정 줄은 담아 돌려주세요');
  });
}
