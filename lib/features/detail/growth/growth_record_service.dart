import 'package:supabase_flutter/supabase_flutter.dart';

import 'growth_record.dart';

/// growth_records 테이블 접근. RLS가 본인 아이의 기록만 돌려줍니다.
class GrowthRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<GrowthRecord>> loadRecords(String babyId) async {
    final rows = await _client
        .from('growth_records')
        .select()
        .eq('baby_id', babyId)
        .order('recorded_on');

    return rows.map(GrowthRecord.fromMap).toList();
  }

  /// 측정일 기준으로 저장합니다.
  ///
  /// 테이블에 UNIQUE(baby_id, recorded_on) 제약이 있어 하루 한 건만 남습니다.
  /// 같은 날짜를 다시 입력하면 오류 대신 기존 값을 덮어씁니다(측정값 정정).
  static Future<void> saveRecord({
    required String babyId,
    required DateTime date,
    double? heightCm,
    double? weightKg,
  }) async {
    await _client.from('growth_records').upsert(
      {
        'baby_id': babyId,
        'recorded_on': date.toIso8601String().split('T').first,
        'height_cm': heightCm,
        'weight_kg': weightKg,
      },
      onConflict: 'baby_id,recorded_on',
    );
  }

  static Future<void> deleteRecord(String id) async {
    await _client.from('growth_records').delete().eq('id', id);
  }
}
