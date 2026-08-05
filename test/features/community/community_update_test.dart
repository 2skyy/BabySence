import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/community/community_service.dart';

/// 글·댓글 수정 시 서버로 보내는 값을 고정합니다.
///
/// RLS가 본인 것만 허용하므로 앱에서 권한을 따로 검사하지 않습니다. 대신
/// **보내는 값 자체가 안전해야** 합니다 — 특히 author_id를 함께 보내면
/// with check에 걸리거나, 최악의 경우 작성자를 바꾸려는 시도가 됩니다.
void main() {
  group('buildPostUpdate', () {
    test('제목과 내용만 보낸다', () {
      final row = CommunityService.buildPostUpdate(
        title: '바뀐 제목',
        body: '바뀐 내용',
      );

      expect(row, {'title': '바뀐 제목', 'body': '바뀐 내용'});
    });

    test('author_id를 보내지 않는다', () {
      // 작성자는 바꿀 이유가 없고, 보내면 RLS의 with check에 걸릴 여지만 생깁니다.
      final row = CommunityService.buildPostUpdate(title: 'a', body: 'b');

      expect(row.containsKey('author_id'), isFalse);
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('created_at'), isFalse);
    });

    test('앞뒤 공백을 지운다', () {
      // DB CHECK가 btrim 길이를 보므로, 공백만 남은 값은 서버에서 거부됩니다.
      final row = CommunityService.buildPostUpdate(
        title: '  제목  ',
        body: '\n 내용 \n',
      );

      expect(row['title'], '제목');
      expect(row['body'], '내용');
    });
  });

  group('buildCommentUpdate', () {
    test('본문만 보낸다', () {
      final row = CommunityService.buildCommentUpdate(body: '수정한 댓글');

      expect(row, {'body': '수정한 댓글'});
    });

    test('post_id와 author_id를 보내지 않는다', () {
      // 댓글이 다른 글로 옮겨가거나 작성자가 바뀌면 안 됩니다.
      final row = CommunityService.buildCommentUpdate(body: 'x');

      expect(row.containsKey('post_id'), isFalse);
      expect(row.containsKey('author_id'), isFalse);
    });

    test('앞뒤 공백을 지운다', () {
      expect(CommunityService.buildCommentUpdate(body: '  댓글  ')['body'], '댓글');
    });
  });
}
