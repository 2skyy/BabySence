import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';
import 'package:flutter_project/features/detail/vaccination_service.dart';

/// 기록 화면들이 DB에 넣는 값이 CHECK 제약과 어긋나지 않는지 고정합니다.
/// 어긋나면 앱에서는 조용히 "저장하지 못했습니다"만 뜨고 원인을 찾기 어렵습니다.
void main() {
  group('FeedingType', () {
    test('enum 이름이 feeding_records.feeding_type CHECK 값과 일치', () {
      expect(FeedingType.values.map((e) => e.name),
          ['formula', 'breast', 'solid']);
    });

    test('화면 라벨에서 되돌릴 수 있다', () {
      expect(FeedingType.fromLabel('분유'), FeedingType.formula);
      expect(FeedingType.fromLabel('모유(직수)'), FeedingType.breast);
      expect(FeedingType.fromLabel('이유식'), FeedingType.solid);
    });

    test('모유(직수)만 수유량을 받지 않는다', () {
      // amount_ml은 모유(직수)에서 NULL이어야 합니다(테이블 주석).
      expect(FeedingType.breast.allowsAmount, isFalse);
      expect(FeedingType.formula.allowsAmount, isTrue);
      expect(FeedingType.solid.allowsAmount, isTrue);
    });
  });

  group('DiaperType / StoolState', () {
    test('enum 이름이 CHECK 값과 일치', () {
      expect(DiaperType.values.map((e) => e.name),
          ['urine', 'stool', 'mixed']);
      expect(StoolState.values.map((e) => e.name),
          ['golden', 'green', 'loose', 'hard']);
    });

    test('소변에는 대변 상태가 붙지 않는다', () {
      // diaper_stool_state_consistent 제약: urine이면 stool_state가 NULL이어야 합니다.
      expect(DiaperType.urine.needsStoolState, isFalse);
      expect(DiaperType.stool.needsStoolState, isTrue);
      expect(DiaperType.mixed.needsStoolState, isTrue);
    });

    test('화면 라벨에서 되돌릴 수 있다', () {
      expect(DiaperType.fromLabel('혼합'), DiaperType.mixed);
      expect(StoolState.fromLabel('녹변'), StoolState.green);
    });
  });

  group('Symptom', () {
    test('dbValue가 temperature_symptoms.symptom CHECK 값과 일치', () {
      // enum 이름은 camelCase(runnyNose)이지만 DB는 snake_case(runny_nose)입니다.
      expect(Symptom.values.map((e) => e.dbValue),
          ['cough', 'runny_nose', 'rash', 'vomit', 'diarrhea']);
    });

    test("'없음'과 알 수 없는 값은 증상이 아니다", () {
      // 행이 하나도 없는 상태가 곧 '없음'입니다.
      expect(Symptom.fromLabel('없음'), isNull);
      expect(Symptom.fromLabel('두통'), isNull);
      expect(Symptom.fromLabel('콧물'), Symptom.runnyNose);
    });
  });

  group('VaccinationService.addMonths', () {
    test('개월 수를 더한다', () {
      expect(VaccinationService.addMonths(DateTime(2026, 1, 15), 2),
          DateTime(2026, 3, 15));
    });

    test('해를 넘긴다', () {
      expect(VaccinationService.addMonths(DateTime(2026, 11, 10), 4),
          DateTime(2027, 3, 10));
    });

    test('말일이 없는 달로 가면 그 달의 마지막 날로 맞춘다', () {
      // 1/31 + 1개월은 2/31이 없으므로 2/28이어야 합니다.
      // Dart의 DateTime(2026, 2, 31)은 3월 3일로 넘어가버립니다.
      expect(VaccinationService.addMonths(DateTime(2026, 1, 31), 1),
          DateTime(2026, 2, 28));
      expect(VaccinationService.addMonths(DateTime(2026, 8, 31), 1),
          DateTime(2026, 9, 30));
    });

    test('0개월은 생년월일 그대로', () {
      expect(VaccinationService.addMonths(DateTime(2026, 5, 20), 0),
          DateTime(2026, 5, 20));
    });
  });
}
