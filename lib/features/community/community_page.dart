import 'package:flutter/material.dart';

import '../../core/widgets/common_app_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/stale_notice.dart';
import 'community_models.dart';
import 'community_service.dart';
import 'post_detail_page.dart';
import 'post_write_page.dart';

/// 커뮤니티 글 목록.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Post> _posts = [];

  /// 지금 보고 있는 갈래. null이면 전체입니다.
  PostCategory? _category;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 이 조회가 몇 번째인지.
  ///
  /// 갈래를 빠르게 바꾸면 조회가 겹치는데, 질의에 갈래가 들어가 결과가
  /// 서로 다릅니다. 그대로 두면 **늦게 온 앞 갈래 응답이 뒤 갈래 화면을
  /// 덮습니다** — 고른 것과 보이는 글이 어긋납니다.
  int _loadGen = 0;

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await CommunityService.loadPosts(category: _category);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _posts = posts;
        // 성공했으면 앞선 실패 표시를 지웁니다.
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = '글을 불러오지 못했습니다.';
        _loading = false;
      });
      debugPrint('커뮤니티 조회 실패: $e');
    }
  }

  Future<void> _selectCategory(PostCategory? category) async {
    if (category == _category) return;
    setState(() => _category = category);
    await _load();
  }

  Future<void> _openWrite() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PostWritePage()),
    );
    if (created == true) await _load();
  }

  Future<void> _openDetail(Post post) async {
    // 상세에서 댓글이 늘거나 글이 지워질 수 있어 돌아오면 다시 읽습니다.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(title: '커뮤니티'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWrite,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('글쓰기'),
      ),
      body: Column(
        children: [
          _buildCategoryBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 갈래 고르기 줄.
  ///
  /// 가로로 넘기게 둡니다. 두 줄로 접으면 글 목록이 그만큼 밀려 내려갑니다.
  Widget _buildCategoryBar() {
    Widget chip(String label, PostCategory? value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: value == _category,
            onSelected: (_) => _selectCategory(value),
          ),
        );

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          chip('전체', null),
          for (final c in PostCategory.values) chip(c.label, c),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 이미 목록이 있으면 스피너로 갈아끼우지 않습니다. 갈아끼우면 보던
    // 자리를 잃고, 새로고침할 때마다 화면이 한 번 비었다 돌아옵니다.
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // **손에 든 목록이 있으면 지우지 않습니다.**
    //
    // 실패했다고 보던 글을 통째로 지우면, 방금까지 읽던 것이 사라집니다.
    // 기록·분석·성장 화면은 이미 [StaleNotice]만 얹고 목록을 남기는데
    // 이 화면만 반대로 동작했습니다.
    if (_error != null && _posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 48, color: context.colors.textSecondary),
              SizedBox(height: AppSpacing.lg),
              Text(
                _category == null
                    ? '아직 글이 없습니다.\n첫 글을 남겨보세요.'
                    : '${_category!.label} 이야기가 아직 없습니다.\n첫 글을 남겨보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // 낡았을 수 있다는 사실은 감추지 않습니다. 목록은 남기되
          // 지금 것이 아닐 수 있다고 말합니다.
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: StaleNotice(message: _error!, onRetry: _load),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                96, // 글쓰기 버튼에 가리지 않도록
              ),
              itemCount: _posts.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _buildPostCard(_posts[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    final isMine = post.authorId == CommunityService.currentUserId;

    return InkWell(
      onTap: () => _openDetail(post),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // '전체'에서 보면 어느 갈래인지 알 수 없어 카드에도 붙입니다.
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    post.category.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                if (isMine)
                  Container(
                    margin: const EdgeInsets.only(left: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '내 글',
                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  relativeTime(post.createdAt),
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.chat_bubble_outline,
                    size: 13, color: context.colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
