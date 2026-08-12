import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/growth/growth_chart_axis.dart';

/// 성장 차트에서 축 숫자가 `3.4285714285714284`처럼 찍히던 문제를 막습니다.
///
/// 범위를 fl_chart에 맡기면 눈금이 데이터 최솟값에서 시작하고, 라벨은 실수가
/// 그대로 나옵니다.
void main() {
  group('범위', () {
    test('눈금 간격의 배수로 넓힌다', () {
      final axis = ChartAxis.fit([2.4, 9.7], step: 3);
      expect(axis.min, 0);
      expect(axis.max, 12);
    });

    test('값을 모두 담는다', () {
      final axis = ChartAxis.fit([1.47, 17.3], step: 3);
      expect(axis.min, lessThanOrEqualTo(1.47));
      expect(axis.max, greaterThanOrEqualTo(17.3));
    });

    test('키는 10cm 간격으로 잡는다', () {
      final axis = ChartAxis.fit([46.1, 92.8], step: 10);
      expect(axis.min, 40);
      expect(axis.max, 100);
    });

    test('기록이 하나뿐이어도 납작해지지 않는다', () {
      // min == max면 fl_chart가 눈금을 만들지 못합니다.
      final axis = ChartAxis.fit([9.0], step: 3);
      expect(axis.max, greaterThan(axis.min));
    });

    test('값이 없어도 축은 만든다', () {
      final axis = ChartAxis.fit(const [], step: 3);
      expect(axis.max, greaterThan(axis.min));
    });
  });

  group('라벨', () {
    test('소수점을 남기지 않는다', () {
      const axis = ChartAxis(min: 0, max: 12, step: 3);
      expect(axis.label(3.4285714285714284), '3');
      expect(axis.label(9), '9');
    });

    test('눈금마다 정수로 떨어진다', () {
      // 축이 간격의 배수이므로 눈금 값 자체가 정수입니다. 반올림해서
      // 정수처럼 보이는 것과는 다릅니다.
      final axis = ChartAxis.fit([1.47, 17.3], step: 3);
      for (var v = axis.min; v <= axis.max; v += axis.step) {
        expect(v % axis.step, 0, reason: '$v');
        expect(double.parse(axis.label(v)), v);
      }
    });
  });
}
