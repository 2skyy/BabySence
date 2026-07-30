import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/noise_tracker.dart' show SleepType;
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';

/// DB로 실제 전송되는 행이 CHECK 제약과 어긋나지 않는지 검사합니다.
///
/// 제약을 어기면 앱에서는 "저장하지 못했습니다"만 뜨고 원인을 알 수 없으므로,
/// 부딪히기 쉬운 네 가지 조합을 여기서 고정합니다.
void main() {
  const babyId = 'baby-1';

  group('수유: 모유(직수)는 amount_ml이 NULL', () {
    test('모유(직수)는 수량을 넣어도 NULL로 나간다', () {
      final row = FeedingRecordService.buildRow(
        babyId: babyId,
        type: FeedingType.breast,
        fedAt: DateTime(2026, 7, 30, 9),
        amountMl: 120, // 사용자가 이전에 입력해 남아 있던 값
      );

      expect(row['feeding_type'], 'breast');
      expect(row['amount_ml'], isNull);
    });

    test('분유·이유식은 수량이 그대로 나간다', () {
      for (final type in [FeedingType.formula, FeedingType.solid]) {
        final row = FeedingRecordService.buildRow(
          babyId: babyId,
          type: type,
          fedAt: DateTime(2026, 7, 30, 9),
          amountMl: 120,
        );
        expect(row['amount_ml'], 120, reason: type.name);
      }
    });
  });

  group('배변: 소변은 stool_state가 NULL', () {
    test('소변은 대변 상태를 넘겨도 NULL로 나간다', () {
      // diaper_stool_state_consistent 제약: urine이면 stool_state가 NULL이어야 합니다.
      final row = DiaperRecordService.buildRow(
        babyId: babyId,
        type: DiaperType.urine,
        recordedAt: DateTime(2026, 7, 30, 8, 40),
        stoolState: StoolState.golden, // 화면 기본값이 항상 들어옵니다
      );

      expect(row['diaper_type'], 'urine');
      expect(row['stool_state'], isNull);
    });

    test('대변·혼합은 상태가 반드시 채워진다', () {
      // 같은 제약의 반대쪽: urine이 아니면 stool_state가 NOT NULL이어야 합니다.
      for (final type in [DiaperType.stool, DiaperType.mixed]) {
        final row = DiaperRecordService.buildRow(
          babyId: babyId,
          type: type,
          recordedAt: DateTime(2026, 7, 30, 8, 40),
          stoolState: StoolState.loose,
        );
        expect(row['stool_state'], 'loose', reason: type.name);
      }
    });

    test('상태를 고르지 않아도 NULL이 아니다', () {
      final row = DiaperRecordService.buildRow(
        babyId: babyId,
        type: DiaperType.stool,
        recordedAt: DateTime(2026, 7, 30, 8, 40),
        stoolState: null,
      );
      expect(row['stool_state'], isNotNull);
    });
  });

  group("체온: '없음'은 증상 행을 만들지 않는다", () {
    test('증상이 비어 있으면 행이 하나도 없다', () {
      // 행이 없는 상태가 곧 '없음'입니다. '없음'을 값으로 저장하지 않습니다.
      final rows = TemperatureRecordService.buildSymptomRows(
        recordId: 'temp-1',
        symptoms: const [],
      );
      expect(rows, isEmpty);
    });

    test('고른 증상만 snake_case로 나간다', () {
      final rows = TemperatureRecordService.buildSymptomRows(
        recordId: 'temp-1',
        symptoms: [Symptom.runnyNose, Symptom.cough],
      );

      expect(rows, hasLength(2));
      expect(rows.map((r) => r['symptom']), containsAll(['runny_nose', 'cough']));
      expect(rows.every((r) => r['temperature_record_id'] == 'temp-1'), isTrue);
    });

    test('중복을 제거한다 (복합 PK 위반 방지)', () {
      final rows = TemperatureRecordService.buildSymptomRows(
        recordId: 'temp-1',
        symptoms: [Symptom.cough, Symptom.cough, Symptom.rash],
      );
      expect(rows, hasLength(2));
    });
  });

  group('수면: 자정을 넘긴 밤잠', () {
    test('오후 8시 취침 → 오전 6시 기상은 다음 날로 저장된다', () {
      // sleep_period_valid 제약: ended_at > started_at
      final start = DateTime(2026, 7, 30, 20, 0);
      final end = DateTime(2026, 7, 30, 6, 30); // 같은 날로 계산된 기상 시각

      final row = SleepRecordService.buildRow(
        babyId: babyId,
        type: SleepType.night,
        startedAt: start,
        endedAt: end,
      );

      expect(row['sleep_type'], 'night');

      final saved = DateTime.parse(row['ended_at'] as String);
      expect(saved, DateTime(2026, 7, 31, 6, 30));
      expect(saved.isAfter(start), isTrue);
    });

    test('낮잠처럼 같은 날 안에 끝나면 그대로 저장된다', () {
      final start = DateTime(2026, 7, 30, 13, 0);
      final end = DateTime(2026, 7, 30, 15, 0);

      final row = SleepRecordService.buildRow(
        babyId: babyId,
        type: SleepType.nap,
        startedAt: start,
        endedAt: end,
      );

      expect(row['sleep_type'], 'nap');
      expect(DateTime.parse(row['ended_at'] as String), end);
    });

    test('취침과 기상이 같은 시각이면 하루를 더한다', () {
      // ended_at > started_at을 만족해야 하므로 같아도 밀어줍니다.
      final at = DateTime(2026, 7, 30, 21, 0);
      expect(SleepRecordService.resolveEnd(at, at),
          DateTime(2026, 7, 31, 21, 0));
    });
  });
}
