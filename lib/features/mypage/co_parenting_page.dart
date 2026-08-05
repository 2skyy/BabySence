import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../../core/widgets/common_app_bar.dart';
import 'baby_member_service.dart';

/// 함께 키우기 — 한 아이를 배우자·조부모와 함께 봅니다.
///
/// 상대의 계정을 몰라도 되도록 8자리 코드를 불러주는 방식입니다.
/// 초대 발급은 아이를 등록한 사람만, 수락은 DB 함수만 할 수 있습니다.
class CoParentingPage extends StatefulWidget {
  const CoParentingPage({super.key});

  @override
  State<CoParentingPage> createState() => _CoParentingPageState();
}

class _CoParentingPageState extends State<CoParentingPage> {
  Baby? _baby;
  List<BabyMember> _members = const [];
  bool _loading = true;

  /// 방금 만든 코드. 화면을 벗어나면 다시 볼 수 없으므로 남겨 둡니다.
  String? _issuedCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final baby = await BabyService.loadCurrent();
      final members =
          baby == null ? <BabyMember>[] : await BabyMemberService.loadMembers(baby.id);
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _members = members;
      });
    } catch (e) {
      _showMessage(BabyMemberService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  BabyMember? get _me {
    for (final m in _members) {
      if (m.isMe) return m;
    }
    return null;
  }

  bool get _isOwner => _me?.isOwner ?? false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── 초대 코드 만들기 ───────────────────────────────────────────────────────

  Future<void> _createInvite() async {
    final baby = _baby;
    if (baby == null) return;

    setState(() => _loading = true);
    try {
      final code = await BabyMemberService.createInvite(baby.id);
      if (!mounted) return;
      setState(() => _issuedCode = code);
    } catch (e) {
      _showMessage(BabyMemberService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showMessage('초대 코드를 복사했습니다.');
  }

  // ── 초대 코드 입력 ─────────────────────────────────────────────────────────

  Future<void> _promptJoin() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('초대 코드 입력'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 9, // ABCD-1234
          decoration: const InputDecoration(
            hintText: 'ABCD-1234',
            counterText: '',
          ),
          style: const TextStyle(letterSpacing: 2, fontSize: 18),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('참여하기'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (code == null) return;

    if (BabyMemberService.normalizeCode(code).length != 8) {
      _showMessage('초대 코드는 8자리입니다.');
      return;
    }

    setState(() => _loading = true);
    try {
      await BabyMemberService.acceptInvite(code);
      if (!mounted) return;
      _showMessage('이제 함께 보실 수 있습니다.');
      await _load();
    } catch (e) {
      _showMessage(BabyMemberService.errorMessage(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 내보내기 / 나가기 ──────────────────────────────────────────────────────

  Future<void> _removeMember(BabyMember member) async {
    final baby = _baby;
    if (baby == null) return;

    final isSelf = member.isMe;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isSelf ? '함께 보기를 그만둘까요?' : '${member.name}님을 내보낼까요?'),
        content: Text(
          isSelf
              ? '${baby.name}의 기록을 더 이상 볼 수 없게 됩니다.\n다시 참여하려면 초대 코드가 필요합니다.'
              : '${member.name}님은 ${baby.name}의 기록을 볼 수 없게 됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              isSelf ? '그만두기' : '내보내기',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await BabyMemberService.removeMember(
        babyId: baby.id,
        userId: member.userId,
      );
      if (!mounted) return;
      await _load();
      // 정책이 막으면 삭제는 0행으로 조용히 끝납니다. 목록으로 확인합니다.
      final stillThere = _members.any((m) => m.userId == member.userId);
      if (stillThere) {
        _showMessage('권한이 없어 처리하지 못했습니다.');
      } else if (isSelf) {
        _showMessage('함께 보기를 그만두었습니다.');
      } else {
        _showMessage('${member.name}님을 내보냈습니다.');
      }
    } catch (e) {
      _showMessage(BabyMemberService.errorMessage(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 화면 ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CommonAppBar(title: '함께 키우기'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: _baby == null ? _noBabyBody() : _sharingBody(),
              ),
            ),
    );
  }

  /// 아직 아이가 없는 사람. 초대를 받아 참여하는 길만 열어 둡니다.
  List<Widget> _noBabyBody() => [
        const SizedBox(height: AppSpacing.xxl),
        const Icon(Icons.group_outlined, size: 44, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          '아직 등록된 아이가 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '아이를 직접 등록하거나,\n먼저 등록한 보호자에게 초대 코드를 받아 참여할 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        _joinButton(),
      ];

  List<Widget> _sharingBody() {
    final baby = _baby!;
    return [
      _sectionTitle('${baby.name}을(를) 함께 보는 사람'),
      const SizedBox(height: AppSpacing.sm),
      _card(
        child: Column(
          children: [
            for (var i = 0; i < _members.length; i++) ...[
              if (i > 0) const Divider(height: AppSpacing.xl),
              _memberRow(_members[i]),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      if (_isOwner) ...[
        _sectionTitle('초대하기'),
        const SizedBox(height: AppSpacing.sm),
        _inviteCard(),
        const SizedBox(height: AppSpacing.xl),
      ],
      _sectionTitle('다른 아이에 참여하기'),
      const SizedBox(height: AppSpacing.sm),
      _joinButton(),
    ];
  }

  Widget _memberRow(BabyMember member) {
    // 소유자는 나갈 수 없고(아이가 주인 없이 남습니다), 소유자만 남을 내보냅니다.
    final canRemove =
        !member.isOwner && (member.isMe || _isOwner);

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor:
              member.isOwner ? AppColors.brand : AppColors.primarySurface,
          child: Icon(
            Icons.person,
            size: 20,
            color: member.isOwner ? Colors.white : AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      member.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (member.isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '나',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                member.roleLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (canRemove)
          TextButton(
            onPressed: () => _removeMember(member),
            child: Text(
              member.isMe ? '그만두기' : '내보내기',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// 초대 코드 발급. 만든 코드는 한 번만 쓸 수 있고 7일 뒤 만료됩니다.
  Widget _inviteCard() {
    final code = _issuedCode;

    if (code == null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '초대 코드를 만들어 상대에게 알려주세요.',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              '한 사람만 쓸 수 있고, 7일 뒤 만료됩니다.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _createInvite,
                child: const Text('초대 코드 만들기'),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '이 코드를 상대에게 알려주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              BabyMemberService.formatCode(code),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '화면을 나가면 다시 볼 수 없어요. 필요하면 새로 만들면 됩니다.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _copyCode(BabyMemberService.formatCode(code)),
                  child: const Text('복사'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _createInvite,
                  child: const Text('새로 만들기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _joinButton() => _card(
        onTap: _promptJoin,
        child: const Row(
          children: [
            Icon(Icons.vpn_key_outlined, color: AppColors.primary),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '초대 코드 입력하기',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _card({required Widget child, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    return Material(
      color: AppColors.surface,
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
