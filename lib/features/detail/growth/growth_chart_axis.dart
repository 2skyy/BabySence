/// 성장 차트 세로축의 범위와 라벨.
///
/// 예전에는 범위도 눈금도 fl_chart에 맡겼습니다. 그러면 눈금이 데이터
/// 최솟값(예: 1.4685…)에서 시작하고, 라벨은 `3.4285714285714284`처럼
/// 실수가 그대로 찍혔습니다. 숫자가 깨져 보이던 것이 이것입니다.
///
/// 범위를 눈금 간격의 배수로 맞춰 두면 라벨이 항상 정수로 떨어집니다.
class ChartAxis {
  final double min;
  final double max;

  /// 눈금 간격. 몸무게(kg)와 키(cm)는 자릿수가 달라 값이 다릅니다.
  final double step;

  const ChartAxis({required this.min, required this.max, required this.step});

  /// [values]를 모두 담되, 양 끝을 [step]의 배수로 넓힌 축.
  ///
  /// 값이 비어 있으면 0부터 [step]까지의 축을 줍니다 — 차트를 그릴 수 없는
  /// 상태에서 min과 max가 같아지면 fl_chart가 눈금을 만들지 못합니다.
  factory ChartAxis.fit(Iterable<double> values, {required double step}) {
    assert(step > 0);

    if (values.isEmpty) {
      return ChartAxis(min: 0, max: step, step: step);
    }

    var lowest = values.first;
    var highest = values.first;
    for (final v in values) {
      if (v < lowest) lowest = v;
      if (v > highest) highest = v;
    }

    final min = (lowest / step).floorToDouble() * step;
    var max = (highest / step).ceilToDouble() * step;

    // 값이 눈금에 딱 맞으면 min과 max가 같아질 수 있습니다(기록이 하나뿐일 때).
    if (max <= min) max = min + step;

    return ChartAxis(min: min, max: max, step: step);
  }

  /// 눈금에 적을 말. 소수점이 딸린 실수를 그대로 찍지 않습니다.
  String label(double value) => value.toStringAsFixed(0);
}
