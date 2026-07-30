import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/assessment/assessment.dart';
import 'package:flutter_project/features/detail/assessment/temperature_rules.dart';

/// <표 3> 연령대별 체온 판단 기준의 모든 경계를 고정합니다.
///
/// | 연령      | 정상        | 주의        | 상담 권장            |
/// |-----------|-------------|-------------|----------------------|
/// | 0~3개월   | 36.5~37.5℃ | 37.5~38.0℃ | 38.0℃ 이상 (즉시 병원) |
/// | 3~6개월   | 36.5~37.5℃ | 37.5~38.5℃ | 38.5℃ 이상           |
/// | 6개월 이상 | 36.5~37.5℃ | 38.0~39.0℃ | 39.0℃ 이상           |
///
/// 임계값이 조용히 바뀌면 아기 건강 안내가 틀리므로, 경계값을 하나씩 확인합니다.
void main() {
  AssessmentLevel levelAt(double temp, int months) =>
      TemperatureRules.assess(temperatureC: temp, ageInMonths: months).level;

  group('상담 권장 하한 (연령대별)', () {
    test('0~3개월은 38.0℃', () {
      expect(TemperatureRules.consultThreshold(0), 38.0);
      expect(TemperatureRules.consultThreshold(2), 38.0);
    });

    test('3~6개월은 38.5℃', () {
      // 3개월이 되는 날부터 이 기준입니다([3,6) 구간).
      expect(TemperatureRules.consultThreshold(3), 38.5);
      expect(TemperatureRules.consultThreshold(5), 38.5);
    });

    test('6개월 이상은 39.0℃', () {
      expect(TemperatureRules.consultThreshold(6), 39.0);
      expect(TemperatureRules.consultThreshold(24), 39.0);
    });
  });

  group('0~3개월', () {
    test('정상 범위', () {
      expect(levelAt(36.5, 1), AssessmentLevel.normal); // 하한 포함
      expect(levelAt(37.0, 1), AssessmentLevel.normal);
      expect(levelAt(37.5, 1), AssessmentLevel.normal); // 상한 포함
    });

    test('주의 범위', () {
      expect(levelAt(37.6, 1), AssessmentLevel.caution);
      expect(levelAt(37.9, 1), AssessmentLevel.caution);
    });

    test('38.0℃부터 상담 권장', () {
      expect(levelAt(38.0, 1), AssessmentLevel.consult);
      expect(levelAt(40.0, 1), AssessmentLevel.consult);
    });

    test('생후 3개월 미만은 즉시 병원을 안내한다', () {
      final a = TemperatureRules.assess(temperatureC: 38.2, ageInMonths: 1);
      expect(a.guideText, contains('즉시 병원'));
    });
  });

  group('3~6개월', () {
    test('37.6℃는 주의 (0~3개월과 같은 시작점)', () {
      expect(levelAt(37.6, 4), AssessmentLevel.caution);
    });

    test('38.0℃는 아직 주의 — 0~3개월이면 상담 권장인 값', () {
      expect(levelAt(38.0, 4), AssessmentLevel.caution);
      expect(levelAt(38.0, 1), AssessmentLevel.consult);
    });

    test('38.5℃부터 상담 권장', () {
      expect(levelAt(38.4, 4), AssessmentLevel.caution);
      expect(levelAt(38.5, 4), AssessmentLevel.consult);
    });

    test('즉시 병원 문구는 붙지 않는다', () {
      final a = TemperatureRules.assess(temperatureC: 38.6, ageInMonths: 4);
      expect(a.guideText, isNot(contains('즉시 병원')));
    });
  });

  group('6개월 이상', () {
    test('39.0℃부터 상담 권장', () {
      expect(levelAt(38.9, 8), AssessmentLevel.caution);
      expect(levelAt(39.0, 8), AssessmentLevel.consult);
    });

    test('표에 없는 37.5~38.0℃ 구간은 주의로 본다', () {
      // 표에서 정상은 37.5까지, 주의는 38.0부터라 사이가 비어 있습니다.
      // 0~3·3~6개월과 같이 37.5에서 이어지도록 주의로 처리합니다.
      // 기준이 확정되면 이 테스트와 규칙을 함께 바꿔야 합니다.
      expect(levelAt(37.6, 8), AssessmentLevel.caution);
      expect(levelAt(37.9, 8), AssessmentLevel.caution);
    });
  });

  group('표에 없는 저체온', () {
    test('36.5℃ 미만은 주의로 본다', () {
      // 표는 높은 쪽만 다룹니다. 정상이 범위(36.5~37.5)로 정의되어 있으므로
      // 그 아래를 정상으로 처리하지 않습니다.
      expect(levelAt(36.4, 1), AssessmentLevel.caution);
      expect(levelAt(35.0, 8), AssessmentLevel.caution);
    });

    test('저체온 안내는 다시 재보라고 알린다', () {
      final a = TemperatureRules.assess(temperatureC: 36.0, ageInMonths: 8);
      expect(a.guideText, contains('낮습니다'));
    });
  });

  group('판정 근거 보존', () {
    test('inputs에 입력값과 적용된 임계값이 남는다', () {
      final a = TemperatureRules.assess(temperatureC: 38.7, ageInMonths: 4);

      expect(a.domain, AssessmentDomain.temperature);
      expect(a.inputs['temperature_c'], 38.7);
      expect(a.inputs['age_in_months'], 4);
      expect(a.inputs['consult_threshold_c'], 38.5);
      expect(a.ruleVersion, TemperatureRules.version);
    });

    test('DB에 넣는 행의 값이 CHECK 제약과 맞는다', () {
      final row = TemperatureRules
          .assess(temperatureC: 36.8, ageInMonths: 2)
          .toRow('baby-1');

      expect(row['domain'], 'temperature');
      expect(row['level'], 'normal');
      expect(row['baby_id'], 'baby-1');
      expect(row['guide_text'], isNotEmpty);
      expect(row['rule_version'], isNotEmpty);
    });
  });

  group('AssessmentLevel / AssessmentDomain', () {
    test('enum 이름이 CHECK 값과 일치', () {
      expect(AssessmentLevel.values.map((e) => e.name),
          ['normal', 'caution', 'consult']);
      expect(AssessmentDomain.values.map((e) => e.name), [
        'temperature', 'feeding', 'sleep', 'diaper',
        'growth', 'noise', 'skin', 'overall',
      ]);
    });
  });

  group('ageInMonthsAt', () {
    test('만 개월 수를 센다', () {
      final birth = DateTime(2026, 1, 15);
      expect(ageInMonthsAt(birth, DateTime(2026, 1, 20)), 0);
      expect(ageInMonthsAt(birth, DateTime(2026, 4, 15)), 3);
      expect(ageInMonthsAt(birth, DateTime(2026, 7, 15)), 6);
    });

    test('생일 전날은 아직 이전 개월 수다', () {
      // 3개월과 6개월이 판정 경계라 하루 차이가 기준을 바꿉니다.
      final birth = DateTime(2026, 1, 15);
      expect(ageInMonthsAt(birth, DateTime(2026, 4, 14)), 2);
      expect(ageInMonthsAt(birth, DateTime(2026, 7, 14)), 5);
    });

    test('해를 넘겨도 센다', () {
      expect(ageInMonthsAt(DateTime(2025, 11, 10), DateTime(2026, 7, 30)), 8);
    });

    test('미래 날짜는 0으로 막는다', () {
      expect(ageInMonthsAt(DateTime(2026, 12, 1), DateTime(2026, 7, 30)), 0);
    });
  });
}
