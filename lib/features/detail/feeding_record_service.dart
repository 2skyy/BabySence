import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

/// 수유 방식. enum 이름이 feeding_records.feeding_type의 CHECK 제약
/// (`formula` / `breast` / `solid`)과 그대로 일치해야 합니다.
enum FeedingType {
  formula('분유'),
  breast('모유(직수)'),
  solid('이유식');

  const FeedingType(this.label);

  /// 화면에 표시하는 이름.
  final String label;

  /// 화면의 한글 라벨을 되돌립니다.
  static FeedingType fromLabel(String label) => FeedingType.values.firstWhere(
        (e) => e.label == label,
        orElse: () => FeedingType.formula,
      );

  /// 모유(직수)는 계량이 불가능해 amount_ml을 NULL로 둡니다.
  /// 테이블 주석에 명시된 규칙입니다.
  bool get allowsAmount => this != FeedingType.breast;
}

/// feeding_records 테이블의 한 행.
class FeedingRecord {
  final String id;
  final FeedingType type;
  final DateTime fedAt;
  final int? amountMl;

  const FeedingRecord({
    required this.id,
    required this.type,
    required this.fedAt,
    this.amountMl,
  });

  factory FeedingRecord.fromMap(Map<String, dynamic> map) => FeedingRecord(
        id: map['id'] as String,
        type: FeedingType.values.byName(map['feeding_type'] as String),
        fedAt: DateTime.parse(map['fed_at'] as String).toLocal(),
        amountMl: map['amount_ml'] as int?,
      );

  /// 이력 목록에 보여줄 요약. 모유(직수)는 수량이 없습니다.
  String get summary =>
      amountMl == null ? type.label : '${type.label} · ${amountMl}ml';
}

/// feeding_records 테이블 접근. RLS가 본인 아이의 기록만 다루게 합니다.
class FeedingRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 최근 기록을 최신순으로 가져옵니다.
  static Future<List<FeedingRecord>> loadRecent(String babyId,
      {int limit = 20}) async {
    final rows = await _client
        .from('feeding_records')
        .select()
        .eq('baby_id', babyId)
        .order('fed_at', ascending: false)
        .limit(limit);

    return rows.map(FeedingRecord.fromMap).toList();
  }

  static Future<void> delete(String id) async {
    await _client.from('feeding_records').delete().eq('id', id);
  }

  /// insert할 행을 만듭니다.
  ///
  /// 전송과 분리해 둔 이유는 CHECK 제약을 지키는지 테스트로 확인할 수 있게
  /// 하려는 것입니다. 제약을 어기면 앱에서는 원인 없는 저장 실패로만 보입니다.
  static Map<String, dynamic> buildRow({
    required String babyId,
    required FeedingType type,
    required DateTime fedAt,
    int? amountMl,
  }) {
    return {
      'baby_id': babyId,
      'feeding_type': type.name,
      // 모유(직수)는 수량을 받지 않으므로 값이 들어와도 무시합니다.
      'amount_ml': type.allowsAmount ? amountMl : null,
      'fed_at': toDbTime(fedAt),
    };
  }

  static Future<void> save({
    required String babyId,
    required FeedingType type,
    required DateTime fedAt,
    int? amountMl,
  }) async {
    await _client.from('feeding_records').insert(buildRow(
          babyId: babyId,
          type: type,
          fedAt: fedAt,
          amountMl: amountMl,
        ));
  }
}
