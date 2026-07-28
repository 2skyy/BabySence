import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../routes/app_routes.dart';

class MyPagePage extends StatelessWidget {
  const MyPagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            const SizedBox(height: AppSpacing.md),

            // 👉 리스트를 확장해서 아래까지 채움
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                children: [
                  _buildSectionTitle('Account'),
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    color: const Color(0xFF6C63FF),
                    onTap: () => navigateToSettings(context),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _buildSectionTitle('General'),
                  _buildMenuItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    color: const Color(0xFF4CAF50),
                    onTap: () {},
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMenuItem(
                    icon: Icons.favorite,
                    title: 'Favorites',
                    color: const Color(0xFFFF9800),
                    onTap: () {},
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _buildSectionTitle('Other'),
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    color: const Color(0xFFE53935),
                    onTap: () {},
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 헤더 줄이고 좌측 정렬로 변경 (덜 부담스럽게)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFF6C63FF),
            child: Icon(Icons.person, color: Colors.white),
          ),
          SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'user@email.com',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 📌 섹션 타이틀 추가 → 밋밋함 해결
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🎨 카드 색 살짝 넣어서 무채색 탈출
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), // 👉 핵심 (톤 컬러)
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // 🚀 컨벤션 유지
  void navigateToSettings(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.settings);
  }
}