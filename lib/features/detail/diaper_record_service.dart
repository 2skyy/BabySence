import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

/// 배변 종류. enum 이름이 diaper_records.diaper_type의 CHECK 제약
/// (`urine` / `stool` / `mixed`)과 그대로 일치해야 합니다.
enum DiaperType {
  urine('소변'),
  stool('대변'),
  mixed('혼합');

  const DiaperType(this.label);

  final String label;

  static DiaperType fromLabel(String label) => DiaperType.values.firstWhere(
        (e) => e.label == label,
        orElse: () => DiaperType.urine,
      );

  /// 소변에는 대변 상태가 있을 수 없습니다.
  /// DB의 diaper_stool_state_consistent 제약이 이 모순을 거부합니다.
  bool get needsStoolState => this != DiaperType.urine;
}

/// 대변 상태. CHECK 제약은 `golden` / `green` / `loose` / `hard`입니다.
enum StoolState {
  golden('황금변'),
  green('녹변'),
  loose('묽음'),
  hard('단단함');

  const StoolState(this.label);

  final String label;

  static StoolState fromLabel(String label) => StoolState.values.firstWhere(
        (e) => e.label == label,
        orElse: () => StoolState.golden,
      );
}

/// diaper_records 테이블의 한 행.
class DiaperRecord {
  final String id;
  final DiaperType type;
  final StoolState? stoolState;
  final DateTime recordedAt;

  const DiaperRecord({
    required this.id,
    required this.type,
    required this.recordedAt,
    this.stoolState,
  });

  factory DiaperRecord.fromMap(Map<String, dynamic> map) {
    final state = map['stool_state'] as String?;
    return DiaperRecord(
      id: map['id'] as String,
      type: DiaperType.values.byName(map['diaper_type'] as String),
      stoolState: state == null ? null : StoolState.values.byName(state),
      recordedAt: DateTime.parse(map['recorded_at'] as String).toLocal(),
    );
  }

  /// 이력 목록에 보여줄 요약. 소변은 대변 상태가 없습니다.
  String get summary =>
      stoolState == null ? type.label : '${type.label} · ${stoolState!.label}';
}

/// diaper_records 테이블 접근.
class DiaperRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<DiaperRecord>> loadRecent(String babyId,
      {int limit = 20}) async {
    final rows = await _client
        .from('diaper_records')
        .select()
        .eq('baby_id', babyId)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return rows.map(DiaperRecord.fromMap).toList();
  }

  static Future<void> delete(String id) async {
    await _client.from('diaper_records').delete().eq('id', id);
  }

  /// insert할 행을 만듭니다. 전송과 분리해 CHECK 제약을 테스트로 확인합니다.
  static Map<String, dynamic> buildRow({
    required String babyId,
    required DiaperType type,
    required DateTime recordedAt,
    StoolState? stoolState,
  }) {
    return {
      'baby_id': babyId,
      'diaper_type': type.name,
      // 소변이면 반드시 NULL, 그 외에는 반드시 값이 있어야 합니다(CHECK 제약).
      'stool_state':
          type.needsStoolState ? (stoolState ?? StoolState.golden).name : null,
      'recorded_at': toDbTime(recordedAt),
    };
  }

  static Future<void> save({
    required String babyId,
    required DiaperType type,
    required DateTime recordedAt,
    StoolState? stoolState,
  }) async {
    await _client.from('diaper_records').insert(buildRow(
          babyId: babyId,
          type: type,
          recordedAt: recordedAt,
          stoolState: stoolState,
        ));
  }
}
