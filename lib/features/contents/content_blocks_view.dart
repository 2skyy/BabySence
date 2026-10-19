import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'content_models.dart';

/// 블록 목록을 위젯으로 옮겨 그립니다.
///
/// 여기 등록된 type만 그립니다 — heading·paragraph·alert·image.
/// **모르는 type은 조용히 건너뜁니다.** 새 type을 쓰는 콘텐츠를 먼저
/// 발행해도 구버전 앱이 죽지 않아야 하기 때문입니다. 그 블록만 안 보일
/// 뿐이고, 서버 콘텐츠가 앱을 깨뜨릴 길을 처음부터 만들지 않습니다.
/// (같은 이유로 콘텐츠에는 코드가 실리지 않습니다 — 문자열을 코드로
/// 해석하는 순간 '내려받은 코드 실행'이 되어 스토어 규정과도 부딪힙니다.)
class ContentBlocksView extends StatelessWidget {
  final List<ContentBlock> blocks;

  const ContentBlocksView({super.key, required this.blocks});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final block in blocks) {
      final widget = _build(context, block);
      if (widget == null) continue; // 모르는 type — 이 블록만 건너뜁니다.
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
      children.add(widget);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _build(BuildContext context, ContentBlock block) {
    final colors = context.colors;
    switch (block.type) {
      case 'heading':
        final text = block.text('text');
        if (text == null) return null;
        return Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        );
      case 'paragraph':
        final text = block.text('text');
        if (text == null) return null;
        return Text(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: colors.textPrimary,
          ),
        );
      case 'alert':
        final text = block.text('text');
        if (text == null) return null;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.textPrimary,
            ),
          ),
        );
      case 'image':
        final url = block.text('url');
        if (url == null) return null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            // 그림을 못 받아도 글은 읽혀야 합니다. 깨진 아이콘 대신 대체
            // 문구(alt)를 보여주고, 그것도 없으면 자리만 조용히 비웁니다.
            errorBuilder: (context, error, stack) {
              final alt = block.text('alt');
              if (alt == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: colors.surface,
                child: Text(
                  alt,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              );
            },
          ),
        );
    }
    return null;
  }
}
