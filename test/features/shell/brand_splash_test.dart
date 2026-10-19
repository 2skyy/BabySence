import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/constants/app_colors.dart';
import 'package:flutter_project/features/shell/brand_splash.dart';

void main() {
  testWidgets('앱 이름과 로고, 진행 표시를 보여준다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandSplash()));

    expect(find.text('BabySense'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('showProgress가 false면 진행 표시를 숨긴다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BrandSplash(showProgress: false)),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('BabySense'), findsOneWidget);
  });

  testWidgets('message를 주면 함께 보여준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BrandSplash(message: '연결을 확인하고 있어요')),
    );

    expect(find.text('연결을 확인하고 있어요'), findsOneWidget);
  });

  group('AppColors 대비', () {
    // 로고 색을 그대로 버튼에 쓰면 흰 글씨가 읽히지 않습니다.
    // 계산 근거는 app_colors.dart 주석 참고.
    double luminance(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final la = luminance(a), lb = luminance(b);
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('primary는 흰 글씨와 WCAG AA(4.5)를 만족한다', () {
      expect(ratio(AppColors.primary, Colors.white), greaterThanOrEqualTo(4.5));
    });

    test('brand는 장식용이라 흰 글씨 기준을 만족하지 못한다', () {
      // 이 사실을 테스트로 박아두어, 나중에 brand를 버튼에 쓰지 않게 합니다.
      expect(ratio(AppColors.brand, Colors.white), lessThan(4.5));
    });

    test('primarySurface는 두 테마 모두에서 글씨가 잘 읽힌다', () {
      // 강조 영역은 밝은 테마와 어두운 테마에서 색이 다릅니다. 한쪽만
      // 확인하면 나머지 한쪽에서 글씨가 묻힙니다.
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        expect(ratio(palette.primarySurface, palette.textPrimary),
            greaterThanOrEqualTo(4.5));
      }
    });
  });
}
