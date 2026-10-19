import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/db_time.dart';

/// 앱 전체가 9시간 어긋난 적이 있습니다. 저장할 때만 UTC 변환이 빠져
/// 있었고, 읽을 때는 toLocal()을 하고 있었습니다.
void main() {
  group('시각 (timestamptz)', () {
    test('오프셋을 반드시 붙인다', () {
      // 이게 없으면 PostgreSQL이 세션 시간대(UTC)로 해석합니다.
      // 한국 새벽 3시가 UTC 3시로 저장되고, 읽을 때 낮 12시가 됩니다.
      final out = toDbTime(DateTime(2026, 8, 12, 3, 17));

      expect(out.endsWith('Z'), isTrue, reason: 'UTC 표시가 있어야 합니다');
    });

    test('저장했다가 읽으면 같은 순간이 나온다', () {
      // 앱이 읽는 방식과 똑같이 되돌립니다.
      final original = DateTime(2026, 8, 12, 3, 17);
      final restored = DateTime.parse(toDbTime(original)).toLocal();

      expect(restored, original);
    });

    test('자정 직후도 날짜가 밀리지 않는다', () {
      final original = DateTime(2026, 8, 12, 0, 5);
      final restored = DateTime.parse(toDbTime(original)).toLocal();

      expect(restored, original);
      expect(restored.day, 12);
    });

    test('이미 UTC인 값도 그대로 왕복한다', () {
      final original = DateTime.utc(2026, 8, 12, 3, 17);
      expect(DateTime.parse(toDbTime(original)).toUtc(), original);
    });
  });

  group('날짜 (date)', () {
    test('YYYY-MM-DD로 만든다', () {
      expect(toDbDate(DateTime(2026, 8, 12)), '2026-08-12');
      expect(toDbDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('UTC로 바꾸지 않는다 — 오전 9시 이전에도 날짜가 그대로다', () {
      // 여기에 toUtc()를 쓰면 한국 오전 3시가 전날이 됩니다.
      // 생년월일이 하루 당겨지면 개월 수가 바뀌고, 개월 수는 체온 판정의
      // 경계입니다.
      expect(toDbDate(DateTime(2026, 8, 12, 3, 17)), '2026-08-12');
      expect(toDbDate(DateTime(2026, 8, 12, 0, 1)), '2026-08-12');
    });

    test('시각이 붙어 있어도 날짜만 남긴다', () {
      expect(toDbDate(DateTime(2026, 8, 12, 23, 59)), '2026-08-12');
    });
  });

  test('DB에 시각을 넣을 때 toIso8601String을 직접 쓰지 않는다', () {
    // 이 규칙이 한 곳에만 있어야 다시 어긋나지 않습니다.
    // 날짜 컬럼과 시각 컬럼은 처리가 달라, 각 자리에서 판단하면 틀립니다.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('db_time.dart'))
        .where((f) => f.readAsStringSync().contains('toIso8601String()'))
        .map((f) => f.path)
        .toList()
      ..sort();

    expect(offenders, isEmpty,
        reason: 'toDbTime() 또는 toDbDate()를 쓰세요.\n${offenders.join('\n')}');
  });
}
