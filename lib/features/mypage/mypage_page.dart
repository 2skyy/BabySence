import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/growth_calculator.dart';
import '../../core/widgets/common_app_bar.dart';
import 'baby_edit_page.dart';
import '../../routes/app_routes.dart';
import 'baby_member_service.dart';
import 'co_parenting_page.dart';

/// 마이페이지 — **누구인지**에 대한 것만 둡니다.
///
/// 내 정보 / 아이 / 함께 키우는 사람. 알림·화면·버전 같은 앱 동작 설정은
/// SettingsPage로 보냅니다. 예전에는 두 화면이 같은 항목을 나눠 갖고 있어
/// 어디로 가야 할지 알기 어려웠습니다.
class MyPagePage extends StatefulWidget {
  const MyPagePage({super.key});

  @override
  State<MyPagePage> createState() => _MyPagePageState();
}

class _MyPagePageState extends State<MyPagePage> {
  Baby? _baby;
  bool _loading = true;

  /// 함께 보는 사람 수. 아이가 없거나 조회에 실패하면 null입니다.
  int? _memberCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final baby = await BabyService.loadCurrent();
      final count = baby == null
          ? null
          : (await BabyMemberService.loadMembers(baby.id)).length;
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _memberCount = count;
      });
    } catch (e) {
      debugPrint('아이 정보 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _displayName {
    final name = (_user?.userMetadata?['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = _user?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : '사용자';
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const CommonAppBar(title: '마이페이지'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _sectionTitle('내 정보'),
          const SizedBox(height: AppSpacing.sm),
          _buildProfileCard(),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle('아이'),
          const SizedBox(height: AppSpacing.sm),
          _buildBabyCard(),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle('함께 키우기'),
          const SizedBox(height: AppSpacing.sm),
          _buildCoParentCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );

  /// 내 정보. 이름은 가입 시 넣은 값이 세션에 남아 있어 조회 없이 씁니다.
  Widget _buildProfileCard() {
    return _card(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.brand,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? '',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 등록된 아이. 없으면 온보딩으로 보냅니다.
  Widget _buildBabyCard() {
    if (_loading) {
      return _card(
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final baby = _baby;
    if (baby == null) {
      return _card(
        onTap: () async {
          await Navigator.pushNamed(context, AppRoutes.onboarding);
          if (mounted) _load();
        },
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '아이 정보를 등록해 주세요',
                style: TextStyle(color: context.colors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.textSecondary),
          ],
        ),
      );
    }

    return _card(
      // 예전에는 등록만 있고 고칠 길이 없었습니다. 생년월일은 체온·성장
      // 판정의 기준이라, 틀린 채로 두면 판정도 계속 틀립니다.
      onTap: () => _openEdit(baby),
      child: Row(
        children: [
          const Icon(Icons.child_care, color: AppColors.brand, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baby.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${baby.sex == ChildSex.male ? '남아' : '여아'} · '
                  '${_formatDate(baby.birthDate)} 출생',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textSecondary),
        ],
      ),
    );
  }

  /// 아이 정보 수정으로 갑니다. 고치고 돌아오면 바뀐 값을 바로 반영합니다.
  Future<void> _openEdit(Baby baby) async {
    final updated = await Navigator.push<Baby>(
      context,
      MaterialPageRoute(builder: (_) => BabyEditPage(baby: baby)),
    );
    if (updated != null && mounted) setState(() => _baby = updated);
  }

  /// 함께 키우는 사람 관리.
  ///
  /// 돌아올 때 다시 읽습니다. 초대를 수락해 아이가 새로 생겼거나, 함께 보기를
  /// 그만두어 아이가 사라졌을 수 있습니다.
  Widget _buildCoParentCard() {
    final count = _memberCount;

    return _card(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoParentingPage()),
        );
        if (mounted) _load();
      },
      child: Row(
        children: [
          const Icon(Icons.group_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '함께 보는 사람 관리',
                  style: TextStyle(color: context.colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  count == null
                      ? '배우자나 조부모를 초대할 수 있어요'
                      : count <= 1
                          ? '아직 나 혼자예요'
                          : '$count명이 함께 보고 있어요',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textSecondary),
        ],
      ),
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
    );
  }
}
