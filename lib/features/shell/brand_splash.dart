import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// 앱을 열었을 때 잠깐 보이는 로고 화면.
///
/// 세션 확인처럼 첫 화면을 정하는 동안 표시됩니다. 빈 화면이나 동그란
/// 진행 표시만 두면 "앱이 멈췄나" 싶게 보여서, 로고를 함께 보여줍니다.
///
/// [message]로 진행 상태를 덧붙일 수 있습니다.
class BrandSplash extends StatelessWidget {
  final String? message;

  /// 진행 표시를 숨기고 로고만 보여줍니다(오류 화면 등).
  final bool showProgress;

  const BrandSplash({super.key, this.message, this.showProgress = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘 원본에 이미 배경이 들어 있어 모서리만 둥글립니다.
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 132,
                height: 132,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'BabySense',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아이의 하루를 기록하고 살펴봅니다',
              style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 40),
            if (showProgress)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
