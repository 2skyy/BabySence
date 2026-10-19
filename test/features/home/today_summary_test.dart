import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';
import 'package:flutter_project/features/home/today_summary.dart';

/// 홈 화면이 보여줄 '오늘의 기록' 요약.
///
/// 기록이 없을 때 그럴듯한 값을 지어내면 사용자가 자기 기록으로 오해합니다.
/// 없으면 null이어야 하고, 화면이 '기록 없음'을 쓰도록 합니다.
void main() {
  final now = DateTime(2026, 8, 5, 15, 0);
  final today = DateTime(2026, 8, 5, 9, 30);
  final yesterday = DateTime(2026, 8, 4, 9, 30);

  FeedingRecord feeding(DateTime at, {int? ml}) => FeedingRecord(
        id: 'f', type: FeedingType.formula, fedAt: at, amountMl: ml);
  TemperatureRecord temp(DateTime at, double c) =>
      TemperatureRecord(id: 't', temperatureC: c, measuredAt: at);
  DiaperRecord diaper(DateTime at) =>
      DiaperRecord(id: 'd', type: DiaperType.urine, recordedAt: at);
  SleepRecord sleep(DateTime start, DateTime? end) => SleepRecord(
        id: 's', type: SleepType.night, startedAt: start, endedAt: end);

  TodaySummary build({
    List<FeedingRecord> f = const [],
    List<TemperatureRecord> t = const [],
    List<DiaperRecord> d = const [],
    List<SleepRecord> s = const [],
  }) =>
      TodaySummary.from(
          feedings: f, temperatures: t, diapers: d, sleeps: s, now: now);

  group('기록이 없을 때', () {
    test('모든 값이 null이고 라벨도 null이다', () {
      final sum = build();

      expect(sum.feeding, isNull);
      expect(sum.feedingLabel, isNull);
      expect(sum.temperatureLabel, isNull);
      expect(sum.diaperLabel, isNull);
      expect(sum.sleepLabel, isNull);
      expect(sum.hasAny, isFalse);
    });

    test('어제 기록은 오늘로 치지 않는다', () {
      final sum = build(
        f: [feeding(yesterday, ml: 160)],
        t: [temp(yesterday, 36.5)],
        d: [diaper(yesterday)],
      );

      expect(sum.feeding, isNull);
      expect(sum.temperature, isNull);
      expect(sum.diaper, isNull);
    });
  });

  group('오늘 기록이 있을 때', () {
    test('가장 최근 것을 고른다', () {
      // 서비스가 최신순으로 주므로 목록의 앞쪽이 최근입니다.
      final sum = build(f: [
        feeding(DateTime(2026, 8, 5, 14, 0), ml: 200),
        feeding(DateTime(2026, 8, 5, 9, 0), ml: 100),
      ]);

      expect(sum.feeding!.amountMl, 200);
    });

    test('라벨을 만든다', () {
      final sum = build(
        f: [feeding(today, ml: 160)],
        t: [temp(today, 37.2)],
        d: [diaper(today)],
      );

      expect(sum.feedingLabel, '분유 · 160ml');
      expect(sum.temperatureLabel, '37.2℃');
      expect(sum.diaperLabel, '소변');
      expect(sum.hasAny, isTrue);
    });
  });

  group('수면', () {
    test('어제 밤에 시작해 오늘 아침에 끝난 밤잠도 오늘로 본다', () {
      // 밤잠은 자정을 넘기는 것이 정상입니다.
      final sum = build(s: [
        sleep(DateTime(2026, 8, 4, 21, 0), DateTime(2026, 8, 5, 6, 30)),
      ]);

      expect(sum.sleep, isNotNull);
      expect(sum.sleepLabel, '밤잠 9시간 30분');
    });

    test('아직 끝나지 않았으면 측정 중으로 보여준다', () {
      final sum = build(s: [sleep(DateTime(2026, 8, 5, 13, 0), null)]);

      expect(sum.sleepLabel, '밤잠 측정 중');
    });

    test('어제 안에서 끝난 수면은 오늘로 치지 않는다', () {
      final sum = build(s: [
        sleep(DateTime(2026, 8, 4, 13, 0), DateTime(2026, 8, 4, 15, 0)),
      ]);

      expect(sum.sleep, isNull);
    });
  });
}
