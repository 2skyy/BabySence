import 'package:supabase_flutter/supabase_flutter.dart';

import 'assessment.dart';

/// assessments 테이블 접근.
///
/// 판정은 앱에서 계산하고 결과만 저장합니다. 규칙이 앱 안에 있어야
/// 네트워크 없이도 즉시 안내를 보여줄 수 있습니다.
class AssessmentService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> save({
    required String babyId,
    required Assessment assessment,
  }) async {
    await _client.from('assessments').insert(assessment.toRow(babyId));
  }

  /// 특정 영역의 최근 판정을 가져옵니다.
  static Future<List<Assessment>> loadRecent({
    required String babyId,
    AssessmentDomain? domain,
    int limit = 20,
  }) async {
    var query = _client.from('assessments').select().eq('baby_id', babyId);
    if (domain != null) {
      query = query.eq('domain', domain.name);
    }

    final rows = await query.order('assessed_at', ascending: false).limit(limit);

    return [
      for (final row in rows)
        Assessment(
          domain: AssessmentDomain.values.byName(row['domain'] as String),
          level: AssessmentLevel.values.byName(row['level'] as String),
          guideText: row['guide_text'] as String,
          inputs: Map<String, dynamic>.from(row['inputs'] as Map),
          ruleVersion: row['rule_version'] as String,
          assessedAt: DateTime.parse(row['assessed_at'] as String).toLocal(),
        ),
    ];
  }
}
