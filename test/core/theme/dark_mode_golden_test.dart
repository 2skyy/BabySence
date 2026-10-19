import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/constants/app_colors.dart';
import 'package:flutter_project/core/theme/app_theme.dart';

/// 다크 모드가 실제로 색을 바꾸는지 확인합니다.
///
/// 스위치만 만들고 화면은 그대로인 상태를 막기 위한 테스트입니다.
void main() {
  /// 테마 안에서 `context.colors`를 읽어옵니다.
  Future<AppPalette> paletteOf(WidgetTester tester, ThemeData theme) async {
    late AppPalette palette;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(builder: (context) {
        palette = context.colors;
        return const SizedBox();
      }),
    ));
    return palette;
  }

  testWidgets('밝은 테마는 기존 색을 그대로 쓴다', (tester) async {
    // 다크 모드를 넣으면서 밝은 화면의 모양이 바뀌면 안 됩니다.
    final p = await paletteOf(tester, AppTheme.lightTheme);

    expect(p.background, const Color(0xFFF8FAFC));
    expect(p.surface, Colors.white);
    expect(p.textPrimary, const Color(0xFF111827));
    expect(p.border, const Color(0xFFE5E7EB));
  });

  testWidgets('어두운 테마는 다른 색을 준다', (tester) async {
    final p = await paletteOf(tester, AppTheme.darkTheme);

    expect(p.background, isNot(AppPalette.light.background));
    expect(p.surface, isNot(AppPalette.light.surface));
    expect(p.textPrimary, isNot(AppPalette.light.textPrimary));
  });

  testWidgets('테마 확장이 없으면 밝은 팔레트로 떨어진다', (tester) async {
    // 화면이 깨지는 것보다 낫습니다.
    final p = await paletteOf(tester, ThemeData(useMaterial3: true));
    expect(p.background, AppPalette.light.background);
  });

  group('대비', () {
    /// WCAG 상대 휘도.
    double luminance(Color c) => c.computeLuminance();

    /// 두 색의 명도 대비. 4.5:1이 본문 글씨의 AA 기준입니다.
    double contrast(Color a, Color b) {
      final l1 = luminance(a), l2 = luminance(b);
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('어두운 테마의 본문 글씨가 AA를 넘는다', () {
      const p = AppPalette.dark;
      expect(contrast(p.textPrimary, p.background), greaterThan(4.5));
      expect(contrast(p.textPrimary, p.surface), greaterThan(4.5));
    });

    test('어두운 테마의 보조 글씨도 AA를 넘는다', () {
      // 회색 글씨는 어두운 배경에서 특히 묻히기 쉽습니다.
      const p = AppPalette.dark;
      expect(contrast(p.textSecondary, p.background), greaterThan(4.5));
      expect(contrast(p.textSecondary, p.surface), greaterThan(4.5));
    });

    test('카드와 배경이 구분된다', () {
      // 같으면 화면 구조를 읽을 수 없습니다.
      const p = AppPalette.dark;
      expect(p.surface, isNot(p.background));
      expect(contrast(p.surface, p.background), greaterThan(1.1));
    });

    test('순수한 검정을 쓰지 않는다', () {
      // OLED에서 스크롤 잔상이 남고 경계가 사라집니다.
      expect(AppPalette.dark.background, isNot(Colors.black));
    });

    test('강조색은 두 테마에서 같고 흰 글씨 대비를 지킨다', () {
      expect(contrast(Colors.white, AppColors.primary), greaterThan(4.5));
    });
  });
}
