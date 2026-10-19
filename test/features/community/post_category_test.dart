import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/community/community_models.dart';

/// 갈래 이름이 앱과 DB에서 어긋나면, 글은 올라가는데 목록에서 사라집니다
/// (CHECK에 걸려 저장이 실패하거나, 거르기에 아무것도 안 잡힙니다).
void main() {
  group('DB 값', () {
    test('schema.sql의 CHECK 목록과 같다', () {
      final schema = File('supabase/schema.sql').readAsStringSync();
      final match = RegExp(r"check \(category in \(([^)]*)\)\)").firstMatch(schema);
      expect(match, isNotNull, reason: 'schema.sql에서 category CHECK를 찾지 못했습니다');

      final inSchema = RegExp("'(\\w+)'")
          .allMatches(match!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        PostCategory.values.map((c) => c.dbValue).toSet(),
        inSchema,
        reason: '앱의 갈래와 DB의 CHECK 목록이 다릅니다',
      );
    });

    test('마이그레이션과 schema.sql이 같은 목록을 쓴다', () {
      // 새 DB는 schema.sql로, 기존 DB는 007로 만듭니다. 두 길이 갈리면
      // 어느 쪽으로 만들었느냐에 따라 앱이 달라집니다.
      List<String> valuesIn(String sql) => (RegExp(r"category in \(([^)]*)\)")
              .firstMatch(sql)
              ?.group(1) ??
          '')
          .split(',')
          .map((v) => v.trim().replaceAll("'", ''))
          .where((v) => v.isNotEmpty)
          .toList()
        ..sort();

      expect(
        valuesIn(File('supabase/migrations/007_add_post_category.sql')
            .readAsStringSync()),
        valuesIn(File('supabase/schema.sql').readAsStringSync()),
      );
    });
  });

  group('되돌리기', () {
    test('DB 값에서 갈래를 찾는다', () {
      expect(PostCategory.fromDb('feeding'), PostCategory.feeding);
      expect(PostCategory.fromDb('health'), PostCategory.health);
    });

    test('모르는 값은 그 밖에로 둔다', () {
      // 갈래를 나중에 늘렸을 때, 옛 앱이 목록을 통째로 못 그리면 안 됩니다.
      expect(PostCategory.fromDb('나중에_생긴_갈래'), PostCategory.etc);
      expect(PostCategory.fromDb(null), PostCategory.etc);
    });
  });

  test('글을 읽을 때 갈래가 함께 온다', () {
    final post = Post.fromMap({
      'id': 'p1',
      'author_id': 'a1',
      'title': '제목',
      'body': '내용',
      'category': 'sleep',
      'created_at': '2026-08-12T03:00:00Z',
    });
    expect(post.category, PostCategory.sleep);
  });

  test('갈래가 없는 옛 글도 읽힌다', () {
    // 007을 적용하기 전에 쓰인 글에는 category가 없습니다.
    final post = Post.fromMap({
      'id': 'p1',
      'author_id': 'a1',
      'title': '제목',
      'body': '내용',
      'created_at': '2026-08-12T03:00:00Z',
    });
    expect(post.category, PostCategory.etc);
  });
}
