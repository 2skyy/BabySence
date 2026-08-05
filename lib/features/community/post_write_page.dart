import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common_button.dart';
import 'community_models.dart';
import 'community_service.dart';

/// 글 작성 · 수정.
///
/// [post]가 있으면 수정 모드입니다. 입력 폼이 같아 화면을 따로 두지 않았습니다.
/// 작성에 성공하면 true를, 수정에 성공하면 바뀐 [Post]를 돌려주고 닫힙니다.
class PostWritePage extends StatefulWidget {
  /// null이면 새 글, 있으면 그 글을 수정합니다.
  final Post? post;

  const PostWritePage({super.key, this.post});

  @override
  State<PostWritePage> createState() => _PostWritePageState();
}

class _PostWritePageState extends State<PostWritePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post?.title ?? '');
    _bodyController = TextEditingController(text: widget.post?.body ?? '');
  }

  // DB의 CHECK 제약과 같은 값입니다.
  static const int titleMax = 100;
  static const int bodyMax = 2000;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showMessage('제목과 내용을 모두 입력해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final updated = await CommunityService.updatePost(
          id: widget.post!.id,
          title: title,
          body: body,
        );
        if (!mounted) return;
        Navigator.pop(context, updated);
      } else {
        await CommunityService.createPost(title: title, body: body);
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage(_isEditing ? '글을 수정하지 못했습니다. $e' : '글을 올리지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? '글 수정' : '글쓰기'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_off_outlined,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '작성자는 익명으로 표시됩니다.',
                        style: TextStyle(fontSize: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _titleController,
                maxLength: titleMax,
                decoration: const InputDecoration(
                  labelText: '제목',
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLength: bodyMax,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CommonButton(
                text: _isEditing ? '수정하기' : '올리기',
                isLoading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
