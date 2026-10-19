import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/advice/advice_service.dart';
import 'package:flutter_project/features/detail/assessment/assessment.dart';

/// 서버 없이 확인할 수 있는 부분만 다룹니다.
/// 답변 품질과 프롬프트는 서버(server/tests/test_advice.py)가 담당합니다.
void main() {
  group('맥락 만들기', () {
    test('개월 수를 넣는다', () {
      final context = buildAdviceContext(ageInMonths: 2);
      expect(context, contains('생후 2개월'));
    });

    test('판정과 그 근거 버전을 함께 넣는다', () {
      // 어떤 기준으로 나온 판정인지 모델이 알아야 설명이 어긋나지 않습니다.
      final context = buildAdviceContext(
        ageInMonths: 2,
        assessment: const Assessment(
          domain: AssessmentDomain.temperature,
          level: AssessmentLevel.consult,
          guideText: '38.0℃ 이상입니다. 생후 3개월 미만은 즉시 병원 진료가 필요합니다.',
          inputs: {'temperature_c': 38.4},
          ruleVersion: 'temperature-2026-07-30',
        ),
      );

      expect(context, contains('체온'));
      expect(context, contains('상담 권장'));
      expect(context, contains('temperature-2026-07-30'));
      expect(context, contains('즉시 병원 진료'));
    });

    test('최근 기록을 줄마다 넣는다', () {
      final context = buildAdviceContext(
        recentRecords: ['최근 7일: 수유 21회', '어젯밤 수면 8시간'],
      );

      expect(context.split('\n'), hasLength(2));
      expect(context, contains('수유 21회'));
    });

    test('넣을 것이 없으면 빈 문자열', () {
      // 서버는 빈 맥락이면 그 자리를 통째로 비웁니다.
      expect(buildAdviceContext(), isEmpty);
    });

    test('아이 이름을 담지 않는다', () {
      // 외부 서비스로 나가는 개인정보를 줄이려는 것입니다. 이름은 답변에
      // 필요하지도 않습니다.
      final context = buildAdviceContext(
        ageInMonths: 5,
        assessment: const Assessment(
          domain: AssessmentDomain.sleep,
          level: AssessmentLevel.normal,
          guideText: '정상 범위입니다.',
          inputs: {},
          ruleVersion: 'v1',
        ),
      );

      expect(context.toLowerCase(), isNot(contains('name')));
      expect(context, isNot(contains('baby_id')));
    });
  });

  group('영역 이름', () {
    test('enum 이름이 서버의 DOMAINS 키와 같다', () {
      // 어긋나면 서버가 400 "알 수 없는 영역입니다"를 돌려줍니다.
      expect(
        AssessmentDomain.values.map((d) => d.name).toSet(),
        {
          'temperature',
          'feeding',
          'sleep',
          'diaper',
          'growth',
          'noise',
          'skin',
          'overall',
        },
      );
    });
  });

  group('오류', () {
    test('메시지를 그대로 들고 있다', () {
      const e = AdviceException('답변 서버에 연결하지 못했습니다.');
      expect(e.toString(), '답변 서버에 연결하지 못했습니다.');
    });
  });
}
