import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project/features/community/community_models.dart';
import 'package:flutter_project/features/community/community_service.dart';

Comment comment(String authorId, {int minute = 0}) => Comment(
      id: 'c$minute',
      postId: 'p1',
      authorId: authorId,
      body: '내용',
      createdAt: DateTime(2026, 7, 30, 12, minute),
    );

void main() {
  group('AnonymousNames', () {
    test('글쓴이는 번호 대신 글쓴이로 표시된다', () {
      final names = AnonymousNames(postAuthorId: 'A', comments: []);
      expect(names.of('A'), '글쓴이');
    });

    test('댓글에 처음 나온 순서대로 번호를 매긴다', () {
      final names = AnonymousNames(
        postAuthorId: 'A',
        comments: [comment('B', minute: 1), comment('C', minute: 2)],
      );
      expect(names.of('B'), '익명1');
      expect(names.of('C'), '익명2');
    });

    test('같은 사람이 여러 번 달아도 번호는 하나만 쓴다', () {
      final names = AnonymousNames(
        postAuthorId: 'A',
        comments: [
          comment('B', minute: 1),
          comment('C', minute: 2),
          comment('B', minute: 3),
        ],
      );
      expect(names.of('B'), '익명1');
      expect(names.of('C'), '익명2');
    });

    test('글쓴이가 자기 글에 댓글을 달아도 번호를 쓰지 않는다', () {
      final names = AnonymousNames(
        postAuthorId: 'A',
        comments: [comment('A', minute: 1), comment('B', minute: 2)],
      );
      expect(names.of('A'), '글쓴이');
      // 글쓴이가 번호를 가져가지 않으므로 첫 댓글자가 익명1입니다.
      expect(names.of('B'), '익명1');
    });

    test('번호는 글마다 새로 시작한다', () {
      final first = AnonymousNames(
        postAuthorId: 'A',
        comments: [comment('B', minute: 1), comment('C', minute: 2)],
      );
      final second = AnonymousNames(
        postAuthorId: 'X',
        comments: [comment('C', minute: 1), comment('B', minute: 2)],
      );

      // 같은 사람(B)이 글에 따라 다른 번호를 받아 가로질러 추적할 수 없습니다.
      expect(first.of('B'), '익명1');
      expect(second.of('B'), '익명2');
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 7, 30, 12, 0);

    test('1분 미만은 방금 전', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 30)), now: now), '방금 전');
    });

    test('시간 단위까지는 분·시간으로 센다', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5분 전');
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3시간 전');
    });

    test('7일이 넘으면 날짜로 보여준다', () {
      expect(relativeTime(now.subtract(const Duration(days: 3)), now: now), '3일 전');
      expect(relativeTime(DateTime(2026, 7, 1), now: now), '2026.07.01');
    });
  });

  group('Post.fromMap', () {
    test('comments(count)가 오면 댓글 수를 읽는다', () {
      final post = Post.fromMap({
        'id': 'p1',
        'author_id': 'A',
        'title': '제목',
        'body': '내용',
        'created_at': '2026-07-30T03:00:00Z',
        'comments': [
          {'count': 4}
        ],
      });
      expect(post.commentCount, 4);
    });

    test('comments가 없으면 0으로 본다', () {
      final post = Post.fromMap({
        'id': 'p1',
        'author_id': 'A',
        'title': '제목',
        'body': '내용',
        'created_at': '2026-07-30T03:00:00Z',
      });
      expect(post.commentCount, 0);
    });
  });

  group('CommunityService 행 만들기', () {
    test('제목과 내용의 앞뒤 공백을 지운다', () {
      final row = CommunityService.buildPostRow(
        authorId: 'A',
        title: '  제목  ',
        body: '\n내용\n',
      );
      expect(row['title'], '제목');
      expect(row['body'], '내용');
      expect(row['author_id'], 'A');
    });

    test('댓글 행에 글 id와 작성자가 들어간다', () {
      final row = CommunityService.buildCommentRow(
        postId: 'p1',
        authorId: 'B',
        body: ' 댓글 ',
      );
      expect(row['post_id'], 'p1');
      expect(row['author_id'], 'B');
      expect(row['body'], '댓글');
    });
  });
}
