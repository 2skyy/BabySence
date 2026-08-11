import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        palette: AppPalette.light,
        appBarBackground: Colors.white,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
        // 앱바를 배경보다 한 단계 밝게 두어 화면 위쪽 경계가 보이게 합니다.
        appBarBackground: AppPalette.dark.surface,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required Color appBarBackground,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        surface: palette.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: palette.textPrimary,
        elevation: 0,
      ),
      // 화면들이 context.colors로 읽는 값입니다.
      extensions: [palette],
    );
  }
}
