import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_models.dart';

/// posts / comments 테이블 접근.
///
/// 다른 기록 서비스와 달리 **읽기가 전체 공개**입니다. RLS도 그렇게 걸려 있어
/// 조회에 작성자 조건을 넣지 않습니다. 수정·삭제는 RLS가 작성자 본인만
/// 허용하므로, 앱에서 막지 않아도 남의 글은 지워지지 않습니다.
class CommunityService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 현재 로그인한 사용자 id. 로그인 상태가 아니면 null.
  static String? get currentUserId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------- 게시글

  /// posts에 넣을 행. 전송과 분리해 자격증명 없이 검증할 수 있게 합니다.
  static Map<String, dynamic> buildPostRow({
    required String authorId,
    required String title,
    required String body,
    required PostCategory category,
  }) {
    return {
      'author_id': authorId,
      'title': title.trim(),
      'body': body.trim(),
      'category': category.dbValue,
    };
  }

  /// 최신순 목록. 댓글 수를 함께 세어 옵니다.
  ///
  /// [category]가 null이면 전체입니다. 거르기를 앱에서 하지 않고 질의에
  /// 넣는 이유는, 한 갈래만 보려는데 50건을 받아 와 몇 건만 남기면 정작
  /// 그 갈래의 옛 글이 잘려 나가기 때문입니다.
  static Future<List<Post>> loadPosts({
    PostCategory? category,
    int limit = 50,
  }) async {
    var query = _client.from('posts').select('*, comments(count)');
    if (category != null) query = query.eq('category', category.dbValue);

    final rows =
        await query.order('created_at', ascending: false).limit(limit);

    return rows.map(Post.fromMap).toList();
  }

  static Future<Post> createPost({
    required String title,
    required String body,
    required PostCategory category,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    final row = await _client
        .from('posts')
        .insert(buildPostRow(
          authorId: userId,
          title: title,
          body: body,
          category: category,
        ))
        .select()
        .single();

    return Post.fromMap(row);
  }

  /// 수정할 값. 작성과 달리 author_id는 넣지 않습니다.
  /// 바꿀 이유가 없고, 넣으면 RLS의 with check에 걸릴 여지만 생깁니다.
  static Map<String, dynamic> buildPostUpdate({
    required String title,
    required String body,
    required PostCategory category,
  }) {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'category': category.dbValue,
    };
  }

  /// 본인 글만 수정됩니다. 남의 글에 시도하면 RLS가 막아 0건이 바뀌고,
  /// select().single()이 예외를 던집니다.
  static Future<Post> updatePost({
    required String id,
    required String title,
    required String body,
    required PostCategory category,
  }) async {
    final row = await _client
        .from('posts')
        .update(buildPostUpdate(title: title, body: body, category: category))
        .eq('id', id)
        .select()
        .single();

    return Post.fromMap(row);
  }

  /// 글을 지우면 댓글도 함께 사라집니다(FK ON DELETE CASCADE).
  static Future<void> deletePost(String id) async {
    await _client.from('posts').delete().eq('id', id);
  }

  // ---------------------------------------------------------------- 댓글

  static Map<String, dynamic> buildCommentRow({
    required String postId,
    required String authorId,
    required String body,
  }) {
    return {
      'post_id': postId,
      'author_id': authorId,
      'body': body.trim(),
    };
  }

  /// 오래된 순. 익명 번호를 등장 순서대로 매기려면 이 순서여야 합니다.
  static Future<List<Comment>> loadComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select()
        .eq('post_id', postId)
        // 방향을 빼면 기본값이 내림차순이라 익명 번호가 거꾸로 매겨집니다.
        .order('created_at', ascending: true);

    return rows.map(Comment.fromMap).toList();
  }

  static Future<void> addComment({
    required String postId,
    required String body,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    await _client.from('comments').insert(
          buildCommentRow(postId: postId, authorId: userId, body: body),
        );
  }

  static Map<String, dynamic> buildCommentUpdate({required String body}) {
    return {'body': body.trim()};
  }

  /// 본인 댓글만 수정됩니다(RLS).
  static Future<Comment> updateComment({
    required String id,
    required String body,
  }) async {
    final row = await _client
        .from('comments')
        .update(buildCommentUpdate(body: body))
        .eq('id', id)
        .select()
        .single();

    return Comment.fromMap(row);
  }

  static Future<void> deleteComment(String id) async {
    await _client.from('comments').delete().eq('id', id);
  }
}
