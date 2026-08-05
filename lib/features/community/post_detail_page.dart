import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'community_models.dart';
import 'community_service.dart';
import 'post_write_page.dart';

/// 글 상세 + 댓글.
class PostDetailPage extends StatefulWidget {
  final Post post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();

  /// 수정하면 내용이 바뀌므로 상태로 들고 있습니다.
  /// widget.post는 처음 값이라 수정 후에는 화면과 어긋납니다.
  late Post _post;

  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String? get _myId => CommunityService.currentUserId;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _load();
  }

  /// 글 수정 화면을 열고, 바뀐 내용을 받아 화면에 반영합니다.
  Future<void> _editPost() async {
    final updated = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => PostWritePage(post: _post)),
    );
    if (updated == null || !mounted) return;
    setState(() => _post = updated);
  }

  /// 댓글 수정. 입력창 하나뿐이라 다이얼로그로 받습니다.
  Future<void> _editComment(Comment comment) async {
    final controller = TextEditingController(text: comment.body);

    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          maxLength: 500, // DB CHECK와 같은 값
          decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('수정'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (body == null || body.isEmpty || body == comment.body) return;

    try {
      await CommunityService.updateComment(id: comment.id, body: body);
      await _load();
    } catch (e) {
      _showMessage('댓글을 수정하지 못했습니다. $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final comments = await CommunityService.loadComments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '댓글을 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await CommunityService.addComment(postId: _post.id, body: body);
      _commentController.clear();
      await _load();
    } catch (e) {
      _showMessage('댓글을 남기지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeletePost() async {
    final ok = await _confirm('글을 삭제할까요?', '댓글도 함께 사라집니다.');
    if (ok != true) return;

    try {
      await CommunityService.deletePost(_post.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showMessage('삭제하지 못했습니다. $e');
    }
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final ok = await _confirm('댓글을 삭제할까요?', null);
    if (ok != true) return;

    try {
      await CommunityService.deleteComment(comment.id);
      await _load();
    } catch (e) {
      _showMessage('삭제하지 못했습니다. $e');
    }
  }

  Future<bool?> _confirm(String title, String? body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final names = AnonymousNames(
      postAuthorId: post.authorId,
      comments: _comments,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('게시글'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (post.authorId == _myId) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editPost,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDeletePost,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _buildPostBody(post),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '댓글 ${_comments.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        '첫 댓글을 남겨보세요.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._comments.map((c) => _buildComment(c, names)),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostBody(Post post) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text(
                '글쓴이',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                relativeTime(post.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Comment comment, AnonymousNames names) {
    final isMine = comment.authorId == _myId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                names.of(comment.authorId),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                relativeTime(comment.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (isMine) ...[
                InkWell(
                  onTap: () => _editComment(comment),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.edit_outlined,
                        size: 15, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: () => _confirmDeleteComment(comment),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 15, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            comment.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '댓글을 남겨보세요',
                  counterText: '',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: _sending ? null : _sendComment,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
