/// contents 표의 한 행과 그 안의 블록.
///
/// 콘텐츠는 코드가 아니라 데이터입니다. blocks의 [{"type", "props"}] 배열을
/// 앱의 렌더러([ContentBlocksView])가 위젯으로 옮겨 그리므로, 글을 고치는
/// 일은 행을 고치는 일이 되고 **스토어 심사 없이** 이미 설치된 앱에
/// 반영됩니다.
///
/// 파싱은 관대하게 합니다. 서버의 콘텐츠는 앱보다 자주, 앱과 무관하게
/// 바뀌므로 **모양이 어긋난 블록 하나가 화면 전체를 죽이면 안 됩니다.**
/// 배열이 아니면 빈 목록으로, 블록 모양이 아니면 그 블록만 건너뜁니다.
class ContentBlock {
  final String type;
  final Map<String, dynamic> props;

  const ContentBlock({required this.type, this.props = const {}});

  /// blocks 컬럼 값에서 블록 목록을 만듭니다.
  static List<ContentBlock> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final blocks = <ContentBlock>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final type = item['type'];
      if (type is! String || type.isEmpty) continue;
      final props = item['props'];
      blocks.add(ContentBlock(
        type: type,
        props: props is Map ? Map<String, dynamic>.from(props) : const {},
      ));
    }
    return blocks;
  }

  /// 문자열 prop. 없거나 문자열이 아니면 null.
  String? text(String key) {
    final value = props[key];
    return value is String ? value : null;
  }
}

class Content {
  final String id;
  final String title;
  final List<ContentBlock> blocks;
  final DateTime? publishedAt;

  const Content({
    required this.id,
    required this.title,
    required this.blocks,
    this.publishedAt,
  });

  factory Content.fromMap(Map<String, dynamic> map) {
    return Content(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      blocks: ContentBlock.listFrom(map['blocks']),
      publishedAt: map['published_at'] != null
          ? DateTime.tryParse(map['published_at'] as String)?.toLocal()
          : null,
    );
  }
}
