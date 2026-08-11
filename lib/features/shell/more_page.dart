import 'package:flutter/material.dart';

import '../../core/widgets/common_app_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../routes/app_routes.dart';
import 'coming_soon_page.dart';

/// 하단 '전체' 탭.
///
/// 홈 앱바에 있던 설정 진입점을 여기로 옮겼습니다. 마이페이지는 라우트만
/// 등록돼 있고 어디서도 갈 수 없었는데, 이 화면이 진입점이 됩니다.
///
/// 아직 없는 기능은 눌러도 아무 일이 없게 두지 않고 [ComingSoonPage]로 보냅니다.
/// 반응 없는 버튼은 고장으로 보입니다.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  /// pubspec.yaml의 version과 함께 고쳐야 합니다.
  /// 자동으로 읽으려면 package_info_plus가 필요한데, 이 한 줄 때문에
  /// 의존성을 늘리지 않았습니다.
  static const String appVersion = '1.0.0';

  void _openComingSoon(BuildContext context, String title, String description) {
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
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(title: '전체', centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _tile(context, 
                icon: Icons.person_outline,
                label: '마이페이지',
                onTap: () => Navigator.pushNamed(context, AppRoutes.mypage),
              ),
              _tile(context, 
                icon: Icons.settings_outlined,
                label: '설정',
                onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
              ),
              _tile(context, 
                icon: Icons.menu_book_outlined,
                label: '육아 가이드',
                onTap: () => _openComingSoon(
                  context,
                  '육아 가이드',
                  '월령별 발달과 돌봄 정보를\n모아 보여줄 화면입니다.',
                ),
              ),
              _tile(context, 
                icon: Icons.description_outlined,
                label: '진료용 리포트',
                onTap: () => _openComingSoon(
                  context,
                  '진료용 리포트',
                  '기록을 모아 병원에서 보여줄 수 있는\n요약을 만들어 줄 화면입니다.',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _listItem(context, 
            label: '공지사항',
            onTap: () => _openComingSoon(
              context,
              '공지사항',
              '업데이트와 안내를 전하는 화면입니다.',
            ),
          ),
          _divider(context),
          _listItem(context, 
            label: '1:1 문의하기',
            onTap: () => _openComingSoon(
              context,
              '1:1 문의하기',
              '문의를 남기고 답변을 받는 화면입니다.',
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _buildFooter(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              // 글자 배율이 크면 라벨이 두 줄이 됩니다. 넘치지 않게 줄여 씁니다.
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listItem(BuildContext context, {required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: context.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Divider(height: 1, color: context.colors.border);

  /// 로그아웃은 설정 화면의 '계정'에만 둡니다. 두 곳에 두면 어느 쪽이
  /// 정식인지 헷갈리고, 한쪽만 고치는 실수가 생깁니다.
  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Text(
        '버전 $appVersion',
        style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
      ),
    );
  }
}
