import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// 앱을 열었을 때 잠깐 보이는 로고 화면.
///
/// 세션 확인처럼 첫 화면을 정하는 동안 표시됩니다. 빈 화면이나 동그란
/// 진행 표시만 두면 "앱이 멈췄나" 싶게 보여서, 로고를 함께 보여줍니다.
///
/// **안드로이드가 먼저 그리는 시작 화면과 같은 그림입니다.** OS는 앱이 뜨는
/// 동안 `launch_background` 색 위에 `splash_logo`를 화면 정중앙에 그리고, 그
/// 자리를 이 화면이 이어받습니다. 배경색·로고·위치를 맞춰 두어야 두 화면이
/// 한 장면으로 보입니다. 그래서 로고는 [Center]로 정중앙에 고정하고, 글자와
/// 진행 표시는 그 아래에 따로 놓습니다 — 글자 길이가 로고 위치를 밀면 안 됩니다.
///
/// [message]로 진행 상태를 덧붙일 수 있습니다.
class BrandSplash extends StatelessWidget {
  final String? message;

  /// 진행 표시를 숨기고 로고만 보여줍니다(오류 화면 등).
  final bool showProgress;

  const BrandSplash({super.key, this.message, this.showProgress = true});

  /// android/app/src/main/res/values/colors.xml 의 launch_background 와 같은 값.
  static const Color _background = Color(0xFFA6ECC0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/icon/logo_lineart.png',
              width: 150,
              height: 150,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BabySense',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '아이의 하루를 기록하고 살펴봅니다',
                  style: TextStyle(fontSize: 14, color: AppColors.primary),
                ),
                const SizedBox(height: 28),
                if (showProgress)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
