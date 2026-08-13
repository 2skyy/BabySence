import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/db_time.dart';

import 'growth_record.dart';

/// growth_records 테이블 접근. RLS가 본인 아이의 기록만 돌려줍니다.
class GrowthRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<GrowthRecord>> loadRecords(String babyId) async {
    final rows = await _client
        .from('growth_records')
        .select()
        .eq('baby_id', babyId)
        // 오름차순입니다. 차트가 왼쪽부터 그리고, chat_context가 `rows.last`를
        // 가장 최근으로 씁니다. 방향을 빼면 기본값이 내림차순이라 **출생 시
        // 몸무게가 '최근 성장 기록'으로** 상담에 나갑니다.
        .order('recorded_on', ascending: true);

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
      buildRow(babyId: babyId, date: date, heightCm: heightCm, weightKg: weightKg),
      onConflict: 'baby_id,recorded_on',
    );
  }

  /// upsert에 보낼 행.
  ///
  /// **입력하지 않은 값은 아예 빼고 보냅니다.** null을 함께 보내면 upsert가
  /// 그 컬럼을 null로 덮어씁니다. 아침에 몸무게만 적고 저녁에 같은 날짜로
  /// 키만 적으면, 아침에 적은 몸무게가 아무 안내 없이 사라졌습니다.
  ///
  /// 화면이 둘 중 하나만 입력해도 저장을 허용하므로 실제로 일어나는 일입니다.
  static Map<String, dynamic> buildRow({
    required String babyId,
    required DateTime date,
    double? heightCm,
    double? weightKg,
  }) {
    return {
      'baby_id': babyId,
      'recorded_on': toDbDate(date),
      'height_cm': ?heightCm,
      'weight_kg': ?weightKg,
    };
  }

  static Future<void> deleteRecord(String id) async {
    await _client.from('growth_records').delete().eq('id', id);
  }
}
