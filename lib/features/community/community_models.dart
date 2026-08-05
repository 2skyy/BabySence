/// 커뮤니티 게시글.
class Post {
  final String id;
  final String authorId;
  final String title;
  final String body;
  final DateTime createdAt;

  /// 목록에서 보여줄 댓글 수. 상세에서는 쓰지 않아 0입니다.
  final int commentCount;

  const Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.commentCount = 0,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    // 목록 조회에서 comments(count)를 함께 받으면
    // [{'count': 3}] 형태로 들어옵니다.
    var count = 0;
    final raw = map['comments'];
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map && first['count'] is int) count = first['count'] as int;
    }

    return Post(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      commentCount: count,
    );
  }
}

/// 게시글에 달린 댓글.
class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<String, dynamic> map) => Comment(
        id: map['id'] as String,
        postId: map['post_id'] as String,
        authorId: map['author_id'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}

/// 글 하나 안에서 작성자에게 익명 번호를 붙입니다.
///
/// 글쓴이는 '글쓴이', 나머지는 댓글에 처음 등장한 순서대로 '익명1', '익명2'…
/// 번호는 글마다 새로 시작하므로, 여러 글에 댓글을 단 같은 사람을 가로질러
/// 추적할 수 없습니다.
class AnonymousNames {
  final String _postAuthorId;
  final Map<String, String> _assigned = {};
  int _next = 1;

  AnonymousNames({required String postAuthorId, required List<Comment> comments})
      : _postAuthorId = postAuthorId {
    // 목록 순서(작성 시각 오름차순)대로 번호를 매깁니다.
    for (final c in comments) {
      _nameOf(c.authorId);
    }
  }

  String _nameOf(String authorId) {
    if (authorId == _postAuthorId) return '글쓴이';
    return _assigned.putIfAbsent(authorId, () => '익명${_next++}');
  }

  /// 화면에 표시할 이름.
  String of(String authorId) => _nameOf(authorId);
}

/// '방금 전', '3시간 전'처럼 상대 시각으로 표시합니다.
String relativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);

  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';

  return '${time.year}.${time.month.toString().padLeft(2, '0')}.'
      '${time.day.toString().padLeft(2, '0')}';
}
