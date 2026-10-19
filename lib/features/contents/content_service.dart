import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_models.dart';

/// 콘텐츠 갈래. DB의 category CHECK와 같은 값이어야 합니다.
enum ContentCategory {
  notice('notice', '공지사항'),
  guide('guide', '육아 가이드');

  final String dbValue;
  final String label;
  const ContentCategory(this.dbValue, this.label);
}

/// contents 테이블 접근.
///
/// **읽기 전용입니다.** 발행·수정은 운영자가 SQL로 직접 하고, RLS에 쓰기
/// 정책 자체가 없습니다. 발행 전(초안)을 감추는 것도 쿼리가 아니라 RLS가
/// 합니다 — 앱이 조건을 빠뜨려도 초안이 새지 않습니다.
class ContentService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 한 갈래의 발행된 콘텐츠를 최신순으로 읽습니다.
  static Future<List<Content>> loadPublished(ContentCategory category) async {
    // 손으로 발행하는 글이라 수십 건 규모지만, 기본 한도에 말없이 기대지
    // 않고 상한을 명시합니다.
    const limit = 100;
    final rows = await _client
        .from('contents')
        .select()
        .eq('category', category.dbValue)
        .order('published_at', ascending: false)
        .limit(limit);

    return rows.map(Content.fromMap).toList();
  }
}
