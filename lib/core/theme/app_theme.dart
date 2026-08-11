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
    final base = ThemeData(brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        surface: palette.background,
        // 씨앗에서 뽑힌 값 대신 팔레트를 씁니다. 화면이 직접 색을 주지 않는
        // 위젯(대화상자·메뉴 등)은 이 값을 글씨색으로 씁니다.
        onSurface: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: palette.textPrimary,
        elevation: 0,
      ),
      // 색을 지정하지 않은 Text와 TextField 입력 글씨가 이걸 따릅니다.
      // 이게 없으면 어두운 배경에 어두운 글씨가 그려집니다.
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      dividerColor: palette.border,
      // 입력칸의 안내 글씨와 밑줄. 화면마다 따로 칠하지 않아도 되게 합니다.
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: palette.textSecondary),
        labelStyle: TextStyle(color: palette.textSecondary),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      // 화면들이 context.colors로 읽는 값입니다.
      extensions: [palette],
    );
  }
}
