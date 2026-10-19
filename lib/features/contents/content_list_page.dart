import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common_app_bar.dart';
import 'content_blocks_view.dart';
import 'content_models.dart';
import 'content_service.dart';

/// 한 갈래를 읽는 일. 화면이 이것만 통해 읽으므로 테스트가 Supabase 없이
/// 실패·빈 목록·목록 상태를 실제로 돌려 볼 수 있습니다.
typedef ContentLoad = Future<List<Content>> Function();

/// 발행일 표기. 공지는 "며칠 전"보다 정확한 날짜가 맞습니다.
String _dateText(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 한 갈래의 콘텐츠 목록. 공지사항·육아 가이드가 같은 화면을 씁니다.
class ContentListPage extends StatefulWidget {
  final ContentCategory category;

  /// 테스트용 주입 자리. 비우면 실제 조회를 씁니다.
  final ContentLoad? load;

  const ContentListPage({super.key, required this.category, this.load});

  @override
  State<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends State<ContentListPage> {
  List<Content>? _contents;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // **보던 목록은 지우지 않습니다.** 당겨서 새로고침 중에 null로 비우면
    // 목록이 전체 스피너로 깜빡이고, 새로고침이 실패하면 멀쩡히 읽던
    // 글까지 오류 화면에 내주게 됩니다 — 커뮤니티 탭이 같은 실수를 고친
    // 적이 있습니다.
    setState(() => _failed = false);
    try {
      final load =
          widget.load ?? () => ContentService.loadPublished(widget.category);
      final contents = await load();
      if (!mounted) return;
      setState(() => _contents = contents);
    } catch (e) {
      // 실패는 실패로 말합니다. 빈 목록으로 접으면 "아직 글이 없다"가 되어
      // 사용자가 다시 볼 이유를 잃습니다 — 없는 것과 못 읽은 것은 다릅니다.
      if (!mounted) return;
      if (_contents == null) {
        // 처음부터 못 읽은 경우만 전면 오류 화면.
        setState(() => _failed = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로고침하지 못했습니다. 연결을 확인해 주세요.')),
        );
      }
      debugPrint('콘텐츠 조회 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CommonAppBar(title: widget.category.label),
      body: _body(colors),
    );
  }

  Widget _body(AppPalette colors) {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '불러오지 못했습니다.\n연결을 확인하고 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final contents = _contents;
    if (contents == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contents.isEmpty) {
      return Center(
        child: Text(
          '아직 올라온 글이 없습니다.',
          style: TextStyle(fontSize: 15, color: colors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: contents.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: colors.border),
        itemBuilder: (context, index) {
          final content = contents[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xs,
            ),
            title: Text(
              content.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            subtitle: content.publishedAt == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _dateText(content.publishedAt!),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentDetailPage(content: content),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 콘텐츠 한 건. 블록 렌더러가 본문을 그립니다.
class ContentDetailPage extends StatelessWidget {
  final Content content;

  const ContentDetailPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CommonAppBar(title: ''),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              content.title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (content.publishedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _dateText(content.publishedAt!),
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ContentBlocksView(blocks: content.blocks),
          ],
        ),
      ),
    );
  }
}
