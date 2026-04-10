import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../routes/app_routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.detail);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Go to Detail', style: AppTextStyles.title),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.mypage);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Go to MyPage', style: AppTextStyles.title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
