import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/assessment/assessment.dart';
import 'package:flutter_project/features/detail/assessment/temperature_rules.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';

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

  /// 논문 3-3절: "6개월 초과 연령에서는 체온 판정 결과와 함께 입력된 동반
  /// 증상을 반드시 병기하여 제시한다." 근거는 [26] NICE NG143 — 6개월을 넘은
  /// 아이는 체온의 높이만으로 중증 질환 여부를 판단하지 말 것.
  group('동반 증상 병기', () {
    String guide(int months, List<Symptom> symptoms) =>
        TemperatureRules.assess(
          temperatureC: 38.2,
          ageInMonths: months,
          symptoms: symptoms,
        ).guideText;

    test('6개월 이상이면 입력한 증상이 판정에 함께 나온다', () {
      final text = guide(8, [Symptom.cough, Symptom.vomit]);

      expect(text, contains('기침'));
      expect(text, contains('구토'));
    });

    test('증상이 없어도 없다고 밝힌다', () {
      // 칸을 비우면 증상을 묻지 않은 것인지 없는 것인지 알 수 없습니다.
      expect(guide(8, const []), contains('증상은 없습니다'));
    });

    test('체온만으로 판단하지 말라는 안내가 함께 붙는다', () {
      expect(guide(8, const []), contains('체온의 높낮이만으로'));
    });

    test('6개월 미만에는 붙지 않는다', () {
      // 3개월 미만은 발열 자체가 응급 신호라 체온이 곧 판정 근거입니다.
      final text = guide(4, [Symptom.cough]);

      expect(text, isNot(contains('함께 기록한 증상')));
      expect(text, isNot(contains('체온의 높낮이만으로')));
    });

    test('경계는 6개월이다', () {
      // 만 개월은 내림이라 6개월 20일도 6입니다. '초과'로 두면 지침이
      // 가리키는 6~7개월 아이가 통째로 빠집니다.
      expect(TemperatureRules.symptomNote(ageInMonths: 5, symptoms: const []),
          isNull);
      expect(TemperatureRules.symptomNote(ageInMonths: 6, symptoms: const []),
          isNotNull);
    });

    test('판정 문장과 문단으로 나뉜다', () {
      // 한 덩어리로 붙으면 화면에서 병기가 묻힙니다.
      expect(guide(8, [Symptom.rash]).split('\n\n'), hasLength(2));
    });

    test('증상은 나이와 무관하게 근거에 남는다', () {
      // 병기하지 않는 나이라도 무엇을 입력했는지는 보존해야 합니다.
      final a = TemperatureRules.assess(
        temperatureC: 38.2,
        ageInMonths: 2,
        symptoms: [Symptom.diarrhea],
      );

      expect(a.inputs['symptoms'], ['diarrhea']);
    });

    test('같은 증상을 두 번 골라도 근거에는 한 번만 남는다', () {
      final a = TemperatureRules.assess(
        temperatureC: 38.2,
        ageInMonths: 8,
        symptoms: [Symptom.cough, Symptom.cough],
      );

      expect(a.inputs['symptoms'], ['cough']);
    });
  });

  /// 논문 3-8절 안전장치 1: '위험' 대신 '상담 권장'을 쓰고, "~입니다" 같은
  /// 확정적 진단 표현 대신 "~ 가능성이 있습니다" 같은 참고적 표현을 쓴다.
  group('안전장치 1 — 참고적 표현', () {
    test('미열을 단정하지 않는다', () {
      final text =
          TemperatureRules.assess(temperatureC: 37.8, ageInMonths: 8).guideText;

      expect(text, contains('가능성이 있습니다'));
      expect(text, isNot(contains('미열입니다')));
    });

    test('정상 안내는 판정 대상을 체온으로 한정한다', () {
      // "정상 범위입니다"만 두면 아이 상태 전체가 정상이라는 말로 읽힙니다.
      final text =
          TemperatureRules.assess(temperatureC: 37.0, ageInMonths: 8).guideText;

      expect(text, contains('체온은 정상 범위'));
    });

    test("어떤 판정에도 '위험'이라는 단어를 쓰지 않는다", () {
      for (final months in [1, 4, 8]) {
        for (final temp in [36.0, 37.0, 37.8, 38.2, 39.5]) {
          final a =
              TemperatureRules.assess(temperatureC: temp, ageInMonths: months);

          expect(a.guideText, isNot(contains('위험')), reason: '$temp℃ $months개월');
          expect(a.levelLabel, isNot(contains('위험')));
        }
      }
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
