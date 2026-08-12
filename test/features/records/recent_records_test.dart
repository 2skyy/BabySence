import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/features/detail/care/care_record_service.dart';
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/growth/growth_record.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';
import 'package:flutter_project/features/records/recent_records.dart';

void main() {
  FeedingRecord feeding(DateTime at) =>
      FeedingRecord(id: 'f', type: FeedingType.formula, fedAt: at, amountMl: 120);

  DiaperRecord diaper(DateTime at) =>
      DiaperRecord(id: 'd', type: DiaperType.urine, stoolState: null, recordedAt: at);

  SleepRecord sleep(DateTime start, {DateTime? end}) =>
      SleepRecord(id: 's', type: SleepType.night, startedAt: start, endedAt: end);

  TemperatureRecord temp(DateTime at, double c) => TemperatureRecord(
        id: 't',
        temperatureC: c,
        measuredAt: at,
        symptoms: const [],
      );

  GrowthRecord growth(DateTime on, {double? cm, double? kg}) =>
      GrowthRecord(id: 'g', date: on, heightCm: cm, weightKg: kg);

  MedicationRecord medication(DateTime at) => MedicationRecord(
        id: 'm',
        name: '해열시럽',
        reason: MedicationReason.fever,
        takenAt: at,
      );

  HospitalVisit visit(DateTime at) => HospitalVisit(
        id: 'h',
        reason: VisitReason.checkup,
        visitedAt: at,
      );

  group('담는 범위', () {
    test('성장·약·병원도 함께 선다', () {
      // 기록 탭에서 격자를 걷어낸 뒤로는 이 목록이 탭의 전부입니다.
      // 7종 중 4종만 담으면 남긴 기록이 어디에도 안 보입니다.
      final merged = mergeRecentRecords(
        feedings: [feeding(DateTime(2026, 8, 12, 9))],
        growths: [growth(DateTime(2026, 8, 12), kg: 7.4)],
        medications: [medication(DateTime(2026, 8, 12, 14))],
        visits: [visit(DateTime(2026, 8, 12, 11))],
      );

      expect(merged.map((r) => r.kind), containsAll([
        RecordKind.feeding,
        RecordKind.growth,
        RecordKind.medication,
        RecordKind.hospital,
      ]));
    });

    test('성장은 잰 시각을 모른다고 표시한다', () {
      // recorded_on이 date 컬럼이라 시각이 없습니다. '오전 12:00'을 붙이면
      // 자정에 쟀다는 뜻이 됩니다.
      final merged = mergeRecentRecords(
        growths: [growth(DateTime(2026, 8, 12), cm: 65.2, kg: 7.4)],
        feedings: [feeding(DateTime(2026, 8, 12, 9))],
      );

      final g = merged.firstWhere((r) => r.kind == RecordKind.growth);
      expect(g.hasTime, isFalse);

      final f = merged.firstWhere((r) => r.kind == RecordKind.feeding);
      expect(f.hasTime, isTrue);
    });

    test('성장 요약은 있는 값만 적는다', () {
      expect(growthSummary(growth(DateTime(2026, 8, 12), kg: 7.4)), '몸무게 7.4kg');
      expect(growthSummary(growth(DateTime(2026, 8, 12), cm: 65.2)), '키 65.2cm');
      expect(
        growthSummary(growth(DateTime(2026, 8, 12), cm: 65.2, kg: 7.4)),
        '키 65.2cm · 몸무게 7.4kg',
      );
    });
  });

  group('기록 합치기', () {
    test('종류가 섞여도 시간 역순으로 선다', () {
      // 각 서비스는 종류별로만 최신순입니다. 합치면 순서가 무너집니다.
      final merged = mergeRecentRecords(
        feedings: [feeding(DateTime(2026, 8, 4, 9))],
        diapers: [diaper(DateTime(2026, 8, 4, 14))],
        sleeps: [sleep(DateTime(2026, 8, 4, 11))],
        temperatures: [temp(DateTime(2026, 8, 4, 20), 37.2)],
      );

      expect(
        merged.map((r) => r.kind).toList(),
        [
          RecordKind.temperature, // 20시
          RecordKind.diaper, // 14시
          RecordKind.sleep, // 11시
          RecordKind.feeding, // 9시
        ],
      );
    });

    test('아직 끝나지 않은 수면도 목록에 나온다', () {
      // 측정 중인 수면이 빠지면 "지금 자는 중"인 걸 알 수 없습니다.
      final merged = mergeRecentRecords(
        sleeps: [sleep(DateTime(2026, 8, 4, 21))],
      );

      expect(merged, hasLength(1));
      expect(merged.single.summary, contains('측정 중'));
    });

    test('limit을 넘으면 최근 것만 남긴다', () {
      final merged = mergeRecentRecords(
        feedings: [
          for (var h = 0; h < 10; h++) feeding(DateTime(2026, 8, 4, h)),
        ],
        limit: 3,
      );

      expect(merged, hasLength(3));
      expect(merged.first.at.hour, 9); // 가장 최근
      expect(merged.last.at.hour, 7);
    });

    test('기록이 없으면 빈 목록', () {
      expect(mergeRecentRecords(), isEmpty);
    });
  });

  group('날짜 묶기', () {
    test('같은 날 기록을 한 묶음으로 만든다', () {
      final grouped = groupByDay([
        RecentRecord(
            kind: RecordKind.feeding,
            at: DateTime(2026, 8, 4, 9),
            summary: 'a'),
        RecentRecord(
            kind: RecordKind.diaper,
            at: DateTime(2026, 8, 4, 23, 59),
            summary: 'b'),
        RecentRecord(
            kind: RecordKind.sleep, at: DateTime(2026, 8, 3), summary: 'c'),
      ]);

      expect(grouped, hasLength(2));
      expect(grouped[DateTime(2026, 8, 4)], hasLength(2));
      expect(grouped[DateTime(2026, 8, 3)], hasLength(1));
    });
  });

  group('날짜 머리글', () {
    final now = DateTime(2026, 8, 4, 15);

    test('오늘·어제는 이름으로 부른다', () {
      expect(formatDayHeader(DateTime(2026, 8, 4), now: now), '오늘');
      expect(formatDayHeader(DateTime(2026, 8, 3), now: now), '어제');
    });

    test('그 이전은 날짜로 쓴다', () {
      expect(formatDayHeader(DateTime(2026, 8, 2), now: now), '8월 2일');
      expect(formatDayHeader(DateTime(2026, 7, 30), now: now), '7월 30일');
    });
  });

  group('시각 표기', () {
    test('자정은 오전 12시, 정오는 오후 12시', () {
      // 12시간제에서 0시를 '오전 0시'로 쓰면 어색합니다.
      expect(formatTimeOfDay(DateTime(2026, 8, 4, 0, 5)), '오전 12:05');
      expect(formatTimeOfDay(DateTime(2026, 8, 4, 12, 0)), '오후 12:00');
    });

    test('오후 시각을 12시간제로 쓴다', () {
      expect(formatTimeOfDay(DateTime(2026, 8, 4, 13, 7)), '오후 1:07');
      expect(formatTimeOfDay(DateTime(2026, 8, 4, 9, 30)), '오전 9:30');
    });
  });
}
