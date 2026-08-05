import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common_app_bar.dart';
import '../../routes/app_routes.dart';
import '../shell/coming_soon_page.dart';
import '../shell/more_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      // 스택을 남겨두면 뒤로가기로 이전 사용자의 화면에 돌아갈 수 있습니다.
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('로그아웃하지 못했습니다. $e')));
    }
  }

  void _openComingSoon(String title, String description) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComingSoonPage(title: title, description: description),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '설정'),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildSectionTitle('알림'),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: '기록 알림',
            color: AppColors.primary,
            // 스위치로 두면 켜고 끌 수 있어 보이지만 실제로는 아무것도 하지
            // 않습니다. FCM 설정 파일이 없어 푸시 자체가 동작하지 않습니다.
            onTap: () => _openComingSoon(
              '기록 알림',
              '수유·예방접종 시간을 알려주는 기능입니다.\n푸시 설정이 끝나면 켤 수 있습니다.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('화면'),
          _buildMenuItem(
            icon: Icons.dark_mode_outlined,
            title: '다크 모드',
            color: AppColors.textSecondary,
            onTap: () => _openComingSoon(
              '다크 모드',
              '어두운 화면 테마입니다.\n색을 다시 잡은 뒤 제공할 예정입니다.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('앱 정보'),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '버전 ${MorePage.appVersion}',
            color: AppColors.textSecondary,
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('계정'),
          _buildMenuItem(
            icon: Icons.logout,
            title: '로그아웃',
            color: AppColors.error,
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    /// null이면 누를 수 없는 줄(예: 버전 표시)입니다.
    VoidCallback? onTap,
  }) {
    // ListTile은 가장 가까운 Material 위에 배경과 물결 효과를 그립니다.
    // 색을 가진 Container로 감싸면 그 효과가 가려지므로 Material로 색을 냅니다.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          // 누를 수 없는 줄에는 화살표를 두지 않습니다.
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

}
