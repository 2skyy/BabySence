import 'package:flutter/material.dart';

/// 앱 색상.
///
/// 로고(assets/icon/app_icon.png)의 세이지 그린을 기준으로 잡았습니다.
/// 로고 배경은 `#AEE9C6`에서 `#89BA9C`로 이어지는 그라데이션이고 선은 흰색입니다.
///
/// **로고 색을 그대로 버튼에 쓰지 않은 이유**: 흰 글씨와의 명도 대비가
/// `#89BA9C`는 2.19, `#AEE9C6`은 1.38로 WCAG AA 기준(4.5)에 크게 못 미칩니다.
/// 버튼·강조에는 같은 계열의 진한 [primary](4.90)를 쓰고, 로고 색은
/// 장식과 연한 배경에만 씁니다.
///
/// ## 다크 모드
///
/// 여기에는 **두 테마에서 같은 값**만 있습니다. 브랜드색과 강조색은 밝든
/// 어둡든 같은 색이어야 하기 때문입니다. `const` 문맥에서 그대로 쓸 수 있습니다.
///
/// 배경·표면·글씨·테두리처럼 테마마다 달라지는 색은 [AppPalette]에 있고,
/// 화면에서는 `context.colors`로 읽습니다.
///
/// ```dart
/// // ✅ 두 테마에서 같은 색
/// color: AppColors.primary
///
/// // ✅ 밝음/어두움을 따라감
/// color: context.colors.textPrimary
/// ```
class AppColors {
  /// 버튼·링크·강조. 흰 글씨 대비 4.90:1 (AA 통과).
  ///
  /// 두 테마에서 같은 값입니다. 어두운 배경에서도 흰 글씨 대비가 유지됩니다.
  static const Color primary = Color(0xFF4F7A60);

  /// 로고에 쓰인 세이지 그린. 아이콘·삽화 등 장식용입니다.
  /// 이 위에 흰 글씨를 올리지 마세요(대비 2.19).
  static const Color brand = Color(0xFF89BA9C);

  /// 로고 그라데이션의 밝은 쪽.
  static const Color brandLight = Color(0xFFAEE9C6);

  static const Color error = Color(0xFFEF4444);

  // 배경·표면·글씨·테두리는 여기 없습니다. 테마마다 달라야 하므로
  // [AppPalette]에만 있습니다. 상수로도 두면 무심코 그쪽을 쓰게 되고,
  // 그 화면만 다크 모드에서 밝은 채로 남습니다 — 실제로 그렇게 됐었습니다.
}

/// 테마에 따라 달라지는 색.
///
/// 밝은 테마 값은 [AppColors]의 기존 값을 그대로 씁니다 — 다크 모드를 넣으면서
/// 밝은 화면의 모양이 바뀌면 안 됩니다.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color primarySurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// 24시간 원의 수면 호.
  ///
  /// **테마마다 다릅니다.** 원의 바탕 고리가 [border]라, 밝은 테마의
  /// 남색(#3F51B5)을 어두운 테마에 그대로 쓰면 대비가 1.50:1이 되어 정작
  /// 원이 말하려는 것(언제 잤는가)이 보이지 않습니다. 그림 요소는 3:1이
  /// 필요합니다.
  final Color sleepArc;

  /// 원 둘레의 수유 점.
  final Color feedingDot;

  /// 원 둘레의 배변 점.
  ///
  /// 밝은 테마에서 앰버(#FFA000)는 흰 카드 위 대비가 2.04:1로 **어두운
  /// 테마보다 오히려 나빴습니다.** 밝은 쪽을 진하게 잡습니다.
  final Color diaperDot;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.primarySurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.sleepArc,
    required this.feedingDot,
    required this.diaperDot,
  });

  /// 기존 화면과 완전히 같은 값입니다.
  static const light = AppPalette(
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    primarySurface: Color(0xFFE8F5ED),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    // 고리(#E5E7EB) 대비 5.55:1
    sleepArc: Color(0xFF3F51B5),
    // 흰 카드 대비 4.90:1
    feedingDot: Color(0xFF4F7A60),
    // 앰버 그대로면 2.04:1이라 진하게. 흰 카드 대비 4.42:1
    diaperDot: Color(0xFFB26500),
  );

  /// 어두운 테마.
  ///
  /// 순수한 검정(#000)을 쓰지 않았습니다. OLED에서는 스크롤할 때 잔상이 남고,
  /// 카드와 배경의 경계가 사라져 화면 구조를 읽기 어렵습니다.
  ///
  /// 대비는 밝은 테마와 같은 기준(WCAG AA 4.5:1)으로 맞췄습니다.
  /// - textPrimary(#F3F4F6) on background(#111827) → 15.8:1
  /// - textSecondary(#9CA3AF) on surface(#1F2937) → 5.9:1
  static const dark = AppPalette(
    background: Color(0xFF111827),
    surface: Color(0xFF1F2937),
    // 밝은 테마의 연녹색을 그대로 쓰면 눈이 부십니다. 같은 계열을 어둡게.
    primarySurface: Color(0xFF1B3A2A),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    border: Color(0xFF374151),
    // 고리(#374151) 대비 4.46:1. 밝은 테마의 남색은 여기서 1.50:1입니다.
    sleepArc: Color(0xFF9FA8DA),
    // 어두운 카드(#1F2937) 대비 7.09:1. primary 그대로면 3.00:1로 아슬합니다.
    feedingDot: Color(0xFF8FBFA3),
    // 어두운 카드 대비 6.42:1
    diaperDot: Color(0xFFFF8F00),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? primarySurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? sleepArc,
    Color? feedingDot,
    Color? diaperDot,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      primarySurface: primarySurface ?? this.primarySurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      sleepArc: sleepArc ?? this.sleepArc,
      feedingDot: feedingDot ?? this.feedingDot,
      diaperDot: diaperDot ?? this.diaperDot,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      sleepArc: Color.lerp(sleepArc, other.sleepArc, t)!,
      feedingDot: Color.lerp(feedingDot, other.feedingDot, t)!,
      diaperDot: Color.lerp(diaperDot, other.diaperDot, t)!,
    );
  }
}

/// `context.colors.background` 처럼 쓰기 위한 확장.
extension AppColorsX on BuildContext {
  /// 현재 테마의 색. 테마가 바뀌면 이 값도 바뀝니다.
  ///
  /// 테마 확장을 등록하지 않은 곳(테스트에서 맨 MaterialApp을 띄우는 경우 등)
  /// 에서는 밝은 팔레트로 떨어집니다. 화면이 깨지는 것보다 낫습니다.
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  /// 지금이 어두운 테마인지. 그림자·불투명도를 다르게 줄 때 씁니다.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
