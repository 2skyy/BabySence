import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/growth_calculator.dart';
import 'package:flutter_project/features/detail/assessment/assessment.dart';
import 'package:flutter_project/features/detail/assessment/growth_rules.dart';

/// 논문 3-3절: "성장 지표의 정상 범위는 ... 연령별 표준편차 기준을 적용"
/// 출처 [6] WHO Child Growth Standards (2006).
void main() {
  /// 주어진 Z-score가 나오도록 체중을 거꾸로 만듭니다.
  double weightForZ(double z, {int months = 12}) =>
      GrowthCalculator.weightAtZ(ChildSex.male, months.toDouble(), z);

  double heightForZ(double z, {int months = 12}) =>
      GrowthCalculator.lengthAtZ(ChildSex.male, months.toDouble(), z);

  Assessment? assessWeight(double z, {int months = 12}) => GrowthRules.assess(
        sex: ChildSex.male,
        ageInMonths: months.toDouble(),
        weightKg: weightForZ(z, months: months),
      );

  // 경계는 Z-score를 직접 넣어 확인합니다. 체중↔Z 왕복 변환은 부동소수점
  // 오차가 있어 정확히 ±2.0을 만들 수 없습니다.
  group('Z-score 경계 (levelForZ)', () {
    test('±2SD 안은 정상', () {
      expect(GrowthRules.levelForZ(0), AssessmentLevel.normal);
      expect(GrowthRules.levelForZ(1.99), AssessmentLevel.normal);
      expect(GrowthRules.levelForZ(-1.99), AssessmentLevel.normal);
    });

    test('정확히 −2.0은 정상 — WHO는 "less than −2"', () {
      // 이 한 글자(미만/이하)가 논문 인용의 정확도를 좌우합니다.
      expect(GrowthRules.levelForZ(-2.0), AssessmentLevel.normal);
    });

    test('−2SD 미만은 주의 — WHO 저체중(underweight) 경계', () {
      expect(GrowthRules.levelForZ(-2.01), AssessmentLevel.caution);
      expect(GrowthRules.levelForZ(-2.5), AssessmentLevel.caution);
    });

    test('정확히 −3.0은 주의, 미만이면 상담 권장 — WHO 중증 경계', () {
      expect(GrowthRules.levelForZ(-3.0), AssessmentLevel.caution);
      expect(GrowthRules.levelForZ(-3.01), AssessmentLevel.consult);
      expect(GrowthRules.levelForZ(-4.0), AssessmentLevel.consult);
    });

    test('위쪽도 같은 간격으로 본다', () {
      // 위쪽은 출처가 없는 프로젝트 결정입니다(아래 별도 테스트로 명시).
      expect(GrowthRules.levelForZ(2.5), AssessmentLevel.caution);
      expect(GrowthRules.levelForZ(3.5), AssessmentLevel.consult);
    });
  });

  group('실제 측정값으로도 같은 단계가 나온다', () {
    test('또래 평균은 정상', () {
      expect(assessWeight(0)!.level, AssessmentLevel.normal);
    });

    test('많이 낮으면 주의·상담 권장', () {
      expect(assessWeight(-2.5)!.level, AssessmentLevel.caution);
      expect(assessWeight(-3.5)!.level, AssessmentLevel.consult);
    });
  });

  group('체중과 키 결합', () {
    test('둘 중 더 높은 단계를 그 기록의 판정으로 삼는다', () {
      final a = GrowthRules.assess(
        sex: ChildSex.male,
        ageInMonths: 12.0,
        weightKg: weightForZ(0), // 정상
        heightCm: heightForZ(-3.2), // 상담 권장
      );

      expect(a!.level, AssessmentLevel.consult);
    });

    test('한쪽만 입력해도 판정한다', () {
      expect(
        GrowthRules.assess(
          sex: ChildSex.male,
          ageInMonths: 12.0,
          heightCm: heightForZ(0),
        )?.level,
        AssessmentLevel.normal,
      );
    });

    test('둘 다 없으면 판정하지 않는다', () {
      expect(
        GrowthRules.assess(sex: ChildSex.male, ageInMonths: 12.0),
        isNull,
      );
    });
  });

  group('판정하지 않는 경우', () {
    test('WHO 표 범위를 벗어난 나이', () {
      // 표가 0~24개월이라 그 밖에서는 Z-score를 낼 수 없습니다.
      expect(assessWeight(0, months: 25), isNull);
      expect(assessWeight(0, months: -1), isNull);
    });

    test('경계인 24개월은 판정한다', () {
      expect(assessWeight(0, months: 24), isNotNull);
    });
  });

  group('판정 근거', () {
    test('Z-score와 적용 임계값을 함께 남긴다', () {
      // 원본 기록이 지워져도 무슨 근거로 나온 판정인지 남아야 합니다.
      final inputs = assessWeight(-2.5)!.inputs;

      expect(inputs['weight_z'], closeTo(-2.5, 0.05));
      expect(inputs['caution_z'], 2.0);
      expect(inputs['consult_z'], 3.0);
      expect(inputs['age_in_months'], 12);
      expect(inputs['sex'], 'male');
    });

    test('위쪽 경계가 출처 없는 값임을 근거에 남긴다', () {
      // 논문에 인용할 때 아래쪽만 WHO 근거임을 구분할 수 있어야 합니다.
      expect(
        assessWeight(0)!.inputs['upper_bound_is_project_decision'],
        isTrue,
      );
    });

    test('규칙 버전을 남긴다', () {
      expect(assessWeight(0)!.ruleVersion, GrowthRules.version);
    });

    test('영역은 growth', () {
      expect(assessWeight(0)!.domain, AssessmentDomain.growth);
    });
  });

  group('안내 문구', () {
    test('백분위를 등수처럼 말하지 않는다', () {
      // "3백분위"는 등수로 읽혀 오해를 삽니다.
      final guide = assessWeight(-2.5)!.guideText;
      expect(guide, isNot(contains('백분위')));
      expect(guide, contains('또래'));
    });

    test('상담 권장에서는 측정 방법도 확인하라고 안내한다', () {
      // 옷·기저귀 무게 때문에 실제보다 무겁게 잴 수 있습니다.
      expect(assessWeight(-3.5)!.guideText, contains('측정 방법'));
    });

    test('정상에서도 추세를 보라고 안내한다', () {
      expect(assessWeight(0)!.guideText, contains('추세'));
    });
  });

  group('나이는 소수점을 살려 넘긴다', () {
    // 만 개월로 내리면 LMS 표 사이 보간이 죽어, 판정이 최대 한 달 어린
    // 기준으로 계산됩니다. 이 시기에는 한 달 차이가 큽니다.
    test('생후 89일 4.6kg 남아는 주의 이상이다', () {
      const days = 89;
      final exact = days / 30.4375; // 2.92개월

      final z = GrowthCalculator.weightZScore(ChildSex.male, exact, 4.6);
      expect(z, lessThan(-2.0), reason: 'WHO 저체중 구간이어야 합니다');

      final assessment = GrowthRules.assess(
        sex: ChildSex.male,
        ageInMonths: exact,
        weightKg: 4.6,
      );
      expect(assessment!.level, isNot(AssessmentLevel.normal));
    });

    test('같은 아이를 만 개월로 내리면 정상으로 뒤집힌다', () {
      // 고친 것이 무엇인지 남깁니다. 이 값이 판정에 쓰이면 안 됩니다.
      final floored = (89 / 30.4375).floor().toDouble(); // 2.0
      final z = GrowthCalculator.weightZScore(ChildSex.male, floored, 4.6);
      expect(z, greaterThan(-2.0));
    });

    test('판정 근거에 소수점 개월이 남는다', () {
      final a = GrowthRules.assess(
        sex: ChildSex.male,
        ageInMonths: 2.92,
        weightKg: 6.0,
      );
      expect(a!.inputs['age_in_months'], closeTo(2.92, 0.01));
    });
  });
}
