import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/notification_test.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/common_app_bar.dart';
import '../shell/coming_soon_page.dart';
import '../shell/more_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _handleLogout() async {
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

    // **이동은 여기서 하지 않습니다.** main.dart의 MyApp이 MaterialApp 위에서
    // signedOut을 듣고 한 곳에서 처리합니다. gotrue는 서버에 요청을 보내기
    // **전에** 로컬 세션을 지우고 signedOut을 흘리므로 그쪽이 먼저 로그인
    // 화면을 세우고, HTTP 왕복을 기다리던 이쪽이 뒤늦게 같은 호출을 한 번 더
    // 해 방금 만든 화면을 지우고 다시 만들었습니다.
    try {
      // **signOut보다 먼저 지웁니다.** gotrue는 서버 요청 전에 로컬 세션을
      // 버리므로, 뒤에 지우려 하면 로그인하지 않은 상태가 되어 RLS가 막습니다.
      // 남겨 두면 이 폰으로 다음에 로그인한 사람에게 앞사람 알림이 갑니다.
      await PushService.clearToken();

      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // **실패라고 말하지 않습니다.** 세션은 이미 지워진 뒤라 사용자는 어차피
      // 로그아웃된 상태입니다. 예전에는 여기서 실패 안내를 띄웠는데, 지하철처럼
      // 망이 나쁜 곳에서는 이미 로그인 화면으로 넘어간 사람 위로 그 안내가
      // 얹혔습니다 — 성공을 실패라고 말한 셈입니다.
      debugPrint('로그아웃 서버 호출 실패(로컬 세션은 이미 지워짐): $e');
    }
  }

  /// 알림이 실제로 뜨는지 확인합니다.
  ///
  /// 수유·예방접종 알림은 몇 시간 뒤에나 울려 확인이 어렵습니다. 같은 방식으로
  /// 10초 뒤에 한 번 걸어 보고, **예약까지만 확인된 것**과 **알림이 켜져 있는지**를
  /// 나눠 알려줍니다. 안 뜨면 어디를 봐야 하는지도 함께 말합니다.
  Future<void> _testNotification() async {
    final result = await NotificationTest.fire();
    if (!mounted) return;

    if (!result.scheduled) {
      _showNotificationDialog(
        '알림을 걸지 못했습니다',
        '${result.error}',
      );
      return;
    }

    if (result.enabled == false) {
      _showNotificationDialog(
        '알림이 꺼져 있습니다',
        '이 앱의 알림 권한이 꺼져 있어 예약을 걸어도 뜨지 않습니다.\n\n'
            '설정 → 앱 → BabySense → 알림에서 켜 주세요.',
      );
      return;
    }

    _showNotificationDialog(
      '10초 뒤에 알림이 갑니다',
      '이 창을 닫고 기다려 주세요.\n\n'
          '알림이 뜨면 수유·예방접종 알림도 같은 방식으로 뜹니다.\n\n'
          '뜨지 않으면 설정 → 배터리 → 백그라운드 사용 제한에서 '
          'BabySense를 "제한 안 함"으로 바꿔 주세요. '
          '절전 상태에서는 몇 분 늦게 오기도 합니다.',
    );
  }

  void _showNotificationDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
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
      backgroundColor: context.colors.background,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildSectionTitle('알림'),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: '기록 알림',
            color: AppColors.primary,
            // 알림은 기기가 스스로 울립니다(로컬 알림). 켜고 끄는 자리가
            // 기능마다 달라, 여기서는 어디로 가면 되는지만 알려줍니다.
            onTap: () => _openComingSoon(
              '기록 알림',
              '수유 알림은 홈 화면의 수유 카드에서,\n예방접종 알림은 예방접종 화면에서 켤 수 있습니다.',
            ),
          ),
          _buildMenuItem(
            icon: Icons.notifications_active_outlined,
            title: '알림 테스트',
            color: AppColors.primary,
            onTap: _testNotification,
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('화면'),
          _buildDarkModeSection(),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionTitle('앱 정보'),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '버전 ${MorePage.appVersion}',
            color: context.colors.textSecondary,
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

  /// 다크 모드 — 자동 전환과 수동 선택.
  ///
  /// 자동이 켜져 있으면 수동 스위치는 잠깁니다. 둘 다 만질 수 있으면 어느
  /// 쪽이 이기는지 알 수 없습니다.
  Widget _buildDarkModeSection() {
    final theme = ThemeScope.maybeOf(context);

    // 컨트롤러가 없으면(테스트 등) 조작할 수 없으므로 숨깁니다.
    if (theme == null) return const SizedBox.shrink();

    // ListTile은 가장 가까운 Material에 배경과 잉크 효과를 그립니다.
    // 색칠한 Container로 감싸면 그 효과가 가려집니다.
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              Icons.brightness_auto,
              color: context.colors.textSecondary,
            ),
            title: const Text('시간에 따라 자동'),
            subtitle: Text(
              '오후 $darkStartHour시부터 오전 $darkEndHour시까지 어둡게',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            value: theme.isAuto,
            onChanged: (v) => theme.setAuto(v),
          ),
          Divider(height: 1, color: context.colors.border),
          SwitchListTile(
            secondary: Icon(
              Icons.dark_mode_outlined,
              color: context.colors.textSecondary,
            ),
            title: const Text('다크 모드'),
            subtitle: theme.isAuto
                ? Text(
                    '지금은 자동으로 정해집니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  )
                : null,
            value: theme.isDark,
            // 자동일 때는 시각이 정하므로 직접 못 바꿉니다.
            onChanged: theme.isAuto ? null : (v) => theme.setDark(v),
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
        style: TextStyle(color: context.colors.textSecondary, fontWeight: FontWeight.bold),
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
