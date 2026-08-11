import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await CommunityService.loadPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '글을 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
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
      appBar: AppBar(
        title: const Text('커뮤니티'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWrite,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('글쓰기'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
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
                '아직 글이 없습니다.\n첫 글을 남겨보세요.',
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
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          96, // 글쓰기 버튼에 가리지 않도록
        ),
        itemCount: _posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => _buildPostCard(_posts[i]),
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
