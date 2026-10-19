import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/assessment/assessment.dart';
import 'package:flutter_project/features/detail/assessment/noise_rules.dart';

/// 논문 3-3절: "30dB(A) 미만을 정상, 30~50dB(A)를 주의, 50dB(A) 초과를
/// 개선 권장으로 구분"
///
/// 출처 [28] WHO Guidelines for community noise (1999) — 침실 30dB
///      [24] Hugh et al. (2014) — 신생아실 권장 상한 50dB(A)
void main() {
  Assessment? assess(double average, {double max = 40, int samples = 100}) =>
      NoiseRules.assess(
        averageDb: average,
        maxDb: max,
        sampleCount: samples,
      );

  group('임계값 경계', () {
    test('30dB 미만은 정상', () {
      expect(assess(20)!.level, AssessmentLevel.normal);
      expect(assess(29.9)!.level, AssessmentLevel.normal);
    });

    test('30dB부터 주의 — WHO 침실 권고 상한', () {
      expect(assess(30.0)!.level, AssessmentLevel.caution);
      expect(assess(45)!.level, AssessmentLevel.caution);
    });

    test('50dB까지는 주의 — 경계값 포함', () {
      // 논문 표기는 "30~50dB를 주의"이므로 50은 주의에 들어갑니다.
      expect(assess(50.0)!.level, AssessmentLevel.caution);
    });

    test('50dB 초과는 개선 권장 — 신생아실 권장 상한', () {
      expect(assess(50.1)!.level, AssessmentLevel.consult);
      expect(assess(70)!.level, AssessmentLevel.consult);
    });
  });

  group('단계는 평균으로 정한다', () {
    test('최대값이 커도 평균이 낮으면 정상', () {
      // 30dB과 50dB 모두 지속되는 배경 소음 수준을 가리키는 값입니다.
      expect(assess(25, max: 80)!.level, AssessmentLevel.normal);
    });

    test('최대값은 안내 문구에 남는다', () {
      // 경계로 쓰지 않을 뿐 버리지는 않습니다.
      expect(assess(25, max: 80)!.guideText, contains('80.0dB'));
    });
  });

  group('표본이 부족하면 판정하지 않는다', () {
    test('30건 미만은 null', () {
      // 측정을 막 시작한 상태에서 평균은 의미가 없습니다.
      expect(assess(60, samples: 29), isNull);
      expect(assess(60, samples: 0), isNull);
    });

    test('30건부터 판정한다', () {
      expect(assess(60, samples: 30), isNotNull);
    });
  });

  group('표현', () {
    test("소음에서는 '상담 권장'이 아니라 '개선 권장'", () {
      // 소음은 환경 문제입니다. '상담 권장'은 병원에 가라는 말로 읽힙니다.
      final a = assess(60)!;
      expect(a.level, AssessmentLevel.consult); // DB에 저장되는 값은 그대로
      expect(a.levelLabel, '개선 권장'); // 화면에 보이는 이름만 다름
    });

    test('다른 영역은 그대로 상담 권장', () {
      const temperature = Assessment(
        domain: AssessmentDomain.temperature,
        level: AssessmentLevel.consult,
        guideText: '',
        inputs: {},
        ruleVersion: 'v1',
      );
      expect(temperature.levelLabel, '상담 권장');
    });

    test("'위험'이라는 단어를 쓰지 않는다", () {
      // 안전장치 1: 확정적·위협적 표현 대신 행동을 안내합니다.
      for (final db in [20.0, 40.0, 70.0]) {
        expect(assess(db)!.guideText, isNot(contains('위험')));
      }
    });
  });

  group('판정 근거', () {
    test('적용 임계값을 함께 남긴다', () {
      final inputs = assess(60, max: 75, samples: 120)!.inputs;

      expect(inputs['average_db'], 60);
      expect(inputs['max_db'], 75);
      expect(inputs['sample_count'], 120);
      expect(inputs['normal_limit_db'], 30.0);
      expect(inputs['improve_limit_db'], 50.0);
    });

    test('마이크 보정이 검증되지 않았음을 남긴다', () {
      // 이 값이 true가 되려면 실제 소음계와 대조해야 합니다.
      expect(assess(40)!.inputs['mic_offset_calibrated'], isFalse);
    });

    test('영역은 noise', () {
      expect(assess(40)!.domain, AssessmentDomain.noise);
    });
  });
}
