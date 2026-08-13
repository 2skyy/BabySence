import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/features/analysis/weekly_summary.dart';
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';

void main() {
  final now = DateTime(2026, 8, 4, 15);

  FeedingRecord feeding(DateTime at) =>
      FeedingRecord(id: 'f', type: FeedingType.formula, fedAt: at, amountMl: 100);

  DiaperRecord diaper(DateTime at) => DiaperRecord(
        id: 'd',
        type: DiaperType.urine,
        stoolState: null,
        recordedAt: at,
      );

  SleepRecord sleep(DateTime start, {DateTime? end}) =>
      SleepRecord(id: 's', type: SleepType.night, startedAt: start, endedAt: end);

  TemperatureRecord temp(DateTime at, double c) => TemperatureRecord(
        id: 't',
        temperatureC: c,
        measuredAt: at,
        symptoms: const [],
      );

  group('기간 자르기', () {
    test('7일 전(오늘 포함)까지만 센다', () {
      // 7월 29일 자정부터가 범위입니다. 7월 28일은 빠져야 합니다.
      final s = WeeklySummary.from(
        feedings: [
          feeding(DateTime(2026, 8, 4, 9)),
          feeding(DateTime(2026, 7, 29, 0, 1)),
          feeding(DateTime(2026, 7, 28, 23, 59)),
        ],
        diapers: const [],
        sleeps: const [],
        temperatures: const [],
        now: now,
      );

      expect(s.feedingCount, 2);
    });

    test('오늘 늦은 시각 기록도 포함한다', () {
      // 기준 시각(15시)보다 뒤에 찍힌 기록도 오늘 것입니다.
      final s = WeeklySummary.from(
        feedings: [feeding(DateTime(2026, 8, 4, 23))],
        diapers: const [],
        sleeps: const [],
        temperatures: const [],
        now: now,
      );

      expect(s.feedingCount, 1);
    });
  });

  group('수면', () {
    test('끝난 수면만 합산한다', () {
      // 측정 중인 수면은 길이를 알 수 없어 더할 수 없습니다.
      final s = WeeklySummary.from(
        feedings: const [],
        diapers: const [],
        sleeps: [
          sleep(DateTime(2026, 8, 3, 21), end: DateTime(2026, 8, 4, 5)), // 8시간
          sleep(DateTime(2026, 8, 4, 13)), // 측정 중
        ],
        temperatures: const [],
        now: now,
      );

      expect(s.completedSleepCount, 1);
      expect(s.sleepTotal, const Duration(hours: 8));
    });

    test('끝난 수면이 없으면 0이다', () {
      final s = WeeklySummary.from(
        feedings: const [],
        diapers: const [],
        sleeps: [sleep(DateTime(2026, 8, 4, 13))],
        temperatures: const [],
        now: now,
      );

      expect(s.completedSleepCount, 0);
      expect(s.sleepTotal, Duration.zero);
    });
  });

  group('최고 체온', () {
    test('기간 안에서 가장 높은 값을 고른다', () {
      final s = WeeklySummary.from(
        feedings: const [],
        diapers: const [],
        sleeps: const [],
        temperatures: [
          temp(DateTime(2026, 8, 4, 9), 37.1),
          temp(DateTime(2026, 8, 2, 9), 38.6),
          temp(DateTime(2026, 7, 20, 9), 39.9), // 범위 밖
        ],
        now: now,
      );

      expect(s.highestTemperature, 38.6);
    });

    test('기록이 없으면 null이다', () {
      // 0.0으로 두면 '체온 0도'로 읽힙니다.
      final s = WeeklySummary.from(
        feedings: const [],
        diapers: const [],
        sleeps: const [],
        temperatures: const [],
        now: now,
      );

      expect(s.highestTemperature, isNull);
      expect(s.isEmpty, isTrue);
    });
  });

  group('평균', () {
    // **기록한 날 수로 나눕니다.** 7로 고정해 나누면 오늘 가입해 다섯 번
    // 수유한 보호자에게 "하루 평균 0.7회"라고 말하게 됩니다. 기록이 없는
    // 엿새를 0으로 세는 것은 이 클래스가 스스로 적어 둔 "평균을 지어내지
    // 않는다"에 어긋납니다.

    test('하루에 몰아 적으면 그 하루로 나눈다', () {
      final s = WeeklySummary.from(
        feedings: [
          for (var i = 0; i < 14; i++) feeding(DateTime(2026, 8, 4, 1)),
        ],
        diapers: const [],
        sleeps: [
          sleep(DateTime(2026, 8, 3, 21), end: DateTime(2026, 8, 4, 5)),
        ],
        temperatures: const [],
        now: now,
      );

      expect(s.feedingDays, 1);
      expect(s.feedingPerDay, 14.0);
      // 8시간을 하루에 잤습니다.
      expect(s.sleepDays, 1);
      expect(s.sleepPerDay, const Duration(hours: 8));
    });

    test('이틀에 나눠 적으면 이틀로 나눈다', () {
      final s = WeeklySummary.from(
        feedings: [
          for (var i = 0; i < 6; i++) feeding(DateTime(2026, 8, 4, 1)),
          for (var i = 0; i < 4; i++) feeding(DateTime(2026, 8, 5, 1)),
        ],
        diapers: const [],
        sleeps: const [],
        temperatures: const [],
        now: now,
      );

      expect(s.feedingDays, 2);
      expect(s.feedingPerDay, 5.0);
    });

    test('기록이 없으면 0으로 나누지 않는다', () {
      final s = WeeklySummary.from(
        feedings: const [],
        diapers: const [],
        sleeps: const [],
        temperatures: const [],
        now: now,
      );

      expect(s.feedingPerDay, 0);
      expect(s.diaperPerDay, 0);
      expect(s.sleepPerDay, Duration.zero);
    });

    test('날짜가 붙어 있어도 서로 다른 날로 센다', () {
      // 날짜 차를 시간으로 재면 서머타임이 낀 주에 이웃한 두 날이 같은
      // 값을 받아 '기록한 6일'이 되고 평균이 부풀어 오릅니다.
      final s = WeeklySummary.from(
        feedings: [
          for (var d = 29; d <= 31; d++) feeding(DateTime(2026, 7, d, 12)),
          for (var d = 1; d <= 4; d++) feeding(DateTime(2026, 8, d, 12)),
        ],
        diapers: const [],
        sleeps: const [],
        temperatures: const [],
        now: now,
      );

      expect(s.feedingCount, 7);
      expect(s.feedingDays, 7, reason: '달을 넘겨도 이레입니다');
      expect(s.feedingPerDay, 1.0);
    });

    test('근거를 밝힌다', () {
      // 화면에 "하루 평균 5.0회 · 기록한 2일 기준"으로 나갑니다.
      expect(WeeklySummary.basis(2), '기록한 2일 기준');
      expect(WeeklySummary.basis(7), '7일 기준');
    });
  });

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

  test('배변도 센다', () {
    final s = WeeklySummary.from(
      feedings: const [],
      diapers: [
        diaper(DateTime(2026, 8, 4, 9)),
        diaper(DateTime(2026, 8, 1, 9)),
      ],
      sleeps: const [],
      temperatures: const [],
      now: now,
    );

    expect(s.diaperCount, 2);
    expect(s.isEmpty, isFalse);
  });
}
