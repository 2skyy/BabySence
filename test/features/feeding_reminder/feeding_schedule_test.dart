import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/feeding_reminder/feeding_schedule.dart';

/// 홈에는 오래 '다음 수유까지 N시간' 같은 예측을 넣지 않는다는 결정이
/// 있었습니다. 이유는 "아이마다 간격이 다르고 그 기준을 정한 바가 없어
/// 숫자를 지어내는 것이 되기 때문"이었습니다.
///
/// 이제 간격을 **보호자가 정합니다.** 그 선만 지키면 됩니다 — 앱이 대신
/// 정하지 않는다는 것.
void main() {
  final lastFed = DateTime(2026, 8, 12, 11, 30);

  group('다음 시각', () {
    test('마지막 수유에 정한 간격을 더한다', () {
      const gap = Duration(hours: 3);
      final schedule = FeedingSchedule(lastFedAt: lastFed, interval: gap);
      expect(schedule.nextAt, DateTime(2026, 8, 12, 14, 30));
    });

    test('간격을 정하지 않았으면 계산하지 않는다', () {
      // 앱이 임의의 값을 채우면 그 숫자가 근거처럼 읽힙니다.
      final schedule = FeedingSchedule(lastFedAt: lastFed);
      expect(schedule.nextAt, isNull);
      expect(schedule.remainingAt(lastFed), isNull);
    });

    test('수유 기록이 없으면 계산하지 않는다', () {
      const schedule = FeedingSchedule(interval: Duration(hours: 3));
      expect(schedule.nextAt, isNull);
    });
  });

  group('남은 시간', () {
    final schedule =
        FeedingSchedule(lastFedAt: lastFed, interval: const Duration(hours: 3));

    test('아직 남았으면 양수', () {
      final left = schedule.remainingAt(DateTime(2026, 8, 12, 13, 10));
      expect(left, const Duration(hours: 1, minutes: 20));
      expect(schedule.isOverdueAt(DateTime(2026, 8, 12, 13, 10)), isFalse);
    });

    test('지났으면 지났다고 본다', () {
      expect(schedule.isOverdueAt(DateTime(2026, 8, 12, 15, 0)), isTrue);
    });

    test('정확히 그 시각은 아직 지난 것이 아니다', () {
      expect(schedule.isOverdueAt(DateTime(2026, 8, 12, 14, 30)), isFalse);
    });
  });

  group('읽는 말', () {
    test('남은 시간', () {
      expect(formatRemaining(const Duration(hours: 1, minutes: 20)), '1시간 20분 뒤');
      expect(formatRemaining(const Duration(minutes: 40)), '40분 뒤');
      expect(formatRemaining(const Duration(hours: 2)), '2시간 뒤');
    });

    test('지난 시간은 음수로 보여주지 않는다', () {
      // '-1시간'으로 두면 읽는 사람이 한 번 더 생각해야 합니다.
      expect(formatRemaining(const Duration(hours: -1)), '1시간 지났어요');
      expect(formatRemaining(const Duration(minutes: -25)), '25분 지났어요');
    });

    test('지금은 지금이라고 한다', () {
      expect(formatRemaining(Duration.zero), '지금이에요');
      expect(formatRemaining(const Duration(seconds: -20)), '지금이에요');
    });

    test('간격', () {
      expect(formatInterval(const Duration(hours: 3)), '3시간');
      expect(formatInterval(const Duration(hours: 3, minutes: 30)), '3시간 30분');
    });

    test('시각은 오전·오후로', () {
      expect(formatClock(DateTime(2026, 8, 12, 14, 30)), '오후 2:30');
      expect(formatClock(DateTime(2026, 8, 12, 0, 5)), '오전 12:05');
      expect(formatClock(DateTime(2026, 8, 12, 12, 0)), '오후 12:00');
    });
  });

  group('처음 값', () {
    test('개월 수에 따라 다르다', () {
      expect(suggestedInterval(1), const Duration(hours: 3));
      expect(suggestedInterval(5), const Duration(hours: 4));
      expect(suggestedInterval(10), const Duration(hours: 5));
    });

    test('고를 수 있는 값 안에 있다', () {
      // 시트에 없는 값이 미리 골라져 있으면 아무것도 선택돼 보이지 않습니다.
      for (final months in [0, 3, 4, 6, 7, 24]) {
        expect(selectableIntervals, contains(suggestedInterval(months)));
      }
    });
  });
}
