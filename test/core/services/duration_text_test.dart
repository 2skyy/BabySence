import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/duration_text.dart';

/// 같은 잠을 화면마다 다르게 부르지 않도록 한 곳에 둔 함수입니다.
///
/// 예전에는 세 자리가 각자 적어, 50분짜리 낮잠을 원 카드는 '50분'이라 하고
/// 목록과 홈 타일은 '0시간 50분'이라 불렀습니다.
void main() {
  group('시간 표기', () {
    test('시간과 분을 함께 쓴다', () {
      expect(formatDuration(const Duration(hours: 7, minutes: 30)), '7시간 30분');
    });

    test('딱 떨어지면 시간만 쓴다', () {
      expect(formatDuration(const Duration(hours: 8)), '8시간');
    });

    test('한 시간이 안 되면 분만 쓴다', () {
      expect(formatDuration(const Duration(minutes: 45)), '45분');
    });
  });

  test('0시간을 앞에 붙이지 않는다', () {
    // 이 함수를 한 곳에 둔 까닭입니다.
    expect(formatDuration(const Duration(minutes: 50)), '50분');
    expect(formatDuration(const Duration(minutes: 50)).startsWith('0시간'), isFalse);
  });

  test('0분이면 0분이라 말한다', () {
    expect(formatDuration(Duration.zero), '0분');
  });
}
