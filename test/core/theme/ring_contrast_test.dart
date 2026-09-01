import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/constants/app_colors.dart';

/// 24시간 원의 색이 **두 테마 모두에서** 보이는지.
///
/// 수면 색을 `Colors.indigo`로 박아 두었을 때, 어두운 테마에서는 바탕
/// 고리(border #374151) 대비가 1.50:1이라 정작 원이 말하려는 것(언제
/// 잤는가)이 보이지 않았습니다. 배변 점은 반대로 **밝은 테마**에서
/// 앰버가 흰 카드 위 2.04:1이었습니다.
///
/// 색을 생성자로 뺀 것은 이 문제를 막으려던 것인데, 넘기는 값이 테마와
/// 무관한 리터럴이면 그 장치가 아무 일도 하지 않습니다.
void main() {
  double lin(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);

  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 그림 요소는 글씨(4.5)보다 낮은 3:1을 씁니다(WCAG 1.4.11).
  const graphic = 3.0;

  group('밝은 테마', () {
    const p = AppPalette.light;
    test('수면 호가 바탕 고리 위에서 보인다', () {
      expect(contrast(p.sleepArc, p.border), greaterThanOrEqualTo(graphic));
    });
    test('수유·배변 점이 카드 위에서 보인다', () {
      expect(contrast(p.feedingDot, p.surface), greaterThanOrEqualTo(graphic));
      expect(contrast(p.diaperDot, p.surface), greaterThanOrEqualTo(graphic),
          reason: '앰버를 그대로 쓰면 흰 카드 위 2.04:1입니다');
    });
  });

  group('어두운 테마', () {
    const p = AppPalette.dark;
    test('수면 호가 바탕 고리 위에서 보인다', () {
      expect(contrast(p.sleepArc, p.border), greaterThanOrEqualTo(graphic),
          reason: 'indigo를 그대로 쓰면 1.50:1입니다');
    });
    test('수유·배변 점이 카드 위에서 보인다', () {
      expect(contrast(p.feedingDot, p.surface), greaterThanOrEqualTo(graphic));
      expect(contrast(p.diaperDot, p.surface), greaterThanOrEqualTo(graphic));
    });
  });

  test('원이 팔레트에서 색을 받는다', () {
    // 값만 지키면 소용없습니다. 원이 그 값을 **쓰지 않고** 리터럴로 칠하면
    // 팔레트를 아무리 고쳐도 화면은 그대로입니다. 색을 생성자로 뺀 장치가
    // 그때 아무 일도 하지 않습니다.
    final src = File('lib/features/records/day_ring.dart').readAsStringSync();

    for (final literal in ['Colors.indigo', 'Colors.amber']) {
      expect(src.contains(literal), isFalse,
          reason: '$literal 을 박아 두면 테마를 따르지 않습니다');
    }
    for (final slot in ['sleepArc', 'feedingDot', 'diaperDot']) {
      expect(src.contains('context.colors.$slot'), isTrue,
          reason: '$slot 을 팔레트에서 받지 않습니다');
    }
  });

  test('두 테마가 서로 다른 색을 쓴다', () {
    // 같으면 한쪽은 반드시 기준에 못 미칩니다 — 바탕이 정반대이기 때문입니다.
    expect(AppPalette.light.sleepArc, isNot(AppPalette.dark.sleepArc));
    expect(AppPalette.light.diaperDot, isNot(AppPalette.dark.diaperDot));
  });
}
