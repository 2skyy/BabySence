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
class AppColors {
  /// 버튼·링크·강조. 흰 글씨 대비 4.90:1 (AA 통과).
  static const Color primary = Color(0xFF4F7A60);

  /// 로고에 쓰인 세이지 그린. 아이콘·삽화 등 장식용입니다.
  /// 이 위에 흰 글씨를 올리지 마세요(대비 2.19).
  static const Color brand = Color(0xFF89BA9C);

  /// 로고 그라데이션의 밝은 쪽.
  static const Color brandLight = Color(0xFFAEE9C6);

  /// 강조 영역의 연한 배경. 어두운 글씨 대비 15.81:1.
  static const Color primarySurface = Color(0xFFE8F5ED);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color border = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFEF4444);
}
