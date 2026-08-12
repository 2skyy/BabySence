import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

import '../../core/services/sleep_type.dart';

/// sleep_records 테이블 접근 (수동 입력용).
///
/// 소음 측정 중에 만들어지는 수면 기록은 [NoiseTracker]가 직접 다룹니다.
/// 이 서비스는 사용자가 시각을 직접 입력해 남기는 경우를 담당합니다.
/// sleep_records 테이블의 한 행.
class SleepRecord {
  final String id;
  final SleepType type;
  final DateTime startedAt;

  /// null이면 측정이 아직 진행 중입니다(소음 측정으로 만들어진 행).
  final DateTime? endedAt;

  const SleepRecord({
    required this.id,
    required this.type,
    required this.startedAt,
    this.endedAt,
  });

  factory SleepRecord.fromMap(Map<String, dynamic> map) {
    final ended = map['ended_at'] as String?;
    return SleepRecord(
      id: map['id'] as String,
      type: SleepType.values.byName(map['sleep_type'] as String),
      startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
      endedAt: ended == null ? null : DateTime.parse(ended).toLocal(),
    );
  }

  /// 수면 시간. 스키마 설계대로 저장하지 않고 조회 시 계산합니다.
  Duration? get duration => endedAt?.difference(startedAt);

  /// 이력 목록에 보여줄 요약.
  String get summary {
    final d = duration;
    if (d == null) return '${type.label} · 측정 중';
    return '${type.label} · ${d.inHours}시간 ${d.inMinutes % 60}분';
  }
}

/// 한 수면 구간의 소음 통계. WHO 기준과 비교하기 위한 값입니다.
class SleepNoiseStats {
  /// 구간 평균 데시벨. WHO의 LAeq에 대응합니다.
  final double averageDb;

  /// 구간 최대 데시벨. WHO의 LAmax에 대응합니다.
  final double maxDb;

  final int sampleCount;

  const SleepNoiseStats({
    required this.averageDb,
    required this.maxDb,
    required this.sampleCount,
  });

  static const empty =
      SleepNoiseStats(averageDb: 0, maxDb: 0, sampleCount: 0);

  /// 집계 결과 한 행에서 만듭니다(`sleep_noise_stats` RPC).
  factory SleepNoiseStats.fromRow(Map<String, dynamic> row) => SleepNoiseStats(
        averageDb: (row['average_db'] as num? ?? 0).toDouble(),
        maxDb: (row['max_db'] as num? ?? 0).toDouble(),
        sampleCount: (row['sample_count'] as num? ?? 0).toInt(),
      );

  /// 로그 값들에서 직접 계산합니다. 지금은 테스트에서만 씁니다 —
  /// 실제 조회는 DB가 집계합니다([SleepRecordService.loadNoiseStats]).
  factory SleepNoiseStats.fromDecibels(List<double> decibels) {
    if (decibels.isEmpty) return empty;

    var sum = 0.0;
    var max = decibels.first;
    for (final d in decibels) {
      sum += d;
      if (d > max) max = d;
    }

    return SleepNoiseStats(
      averageDb: sum / decibels.length,
      maxDb: max,
      sampleCount: decibels.length,
    );
  }
}

class SleepRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 한 수면 구간에 쌓인 소음 로그의 평균·최대를 구합니다.
  ///
  /// **집계는 DB가 합니다**(009 마이그레이션의 `sleep_noise_stats`).
  /// 예전에는 로그를 limit도 order도 없이 전부 받아 와 앱에서 셌는데,
  /// 하룻밤이면 수만 행이라 PostgREST의 행 상한에 잘렸습니다. 잘린 자리가
  /// 어디인지도 알 수 없어(order 없음) 밤새 잰 결과가 사실상 **측정 시작
  /// 직후 몇 분**의 통계가 됐고, 그 통계로 만든 판정이 저장됐습니다.
  static Future<SleepNoiseStats> loadNoiseStats(String sleepRecordId) async {
    final rows = await _client.rpc(
      'sleep_noise_stats',
      params: {'p_sleep_record_id': sleepRecordId},
    );

    if (rows is List && rows.isNotEmpty) {
      return SleepNoiseStats.fromRow(rows.first as Map<String, dynamic>);
    }
    return SleepNoiseStats.empty;
  }

  static Future<List<SleepRecord>> loadRecent(String babyId,
      {int limit = 20}) async {
    final rows = await _client
        .from('sleep_records')
        .select()
        .eq('baby_id', babyId)
        .order('started_at', ascending: false)
        .limit(limit);

    return rows.map(SleepRecord.fromMap).toList();
  }

  static Future<void> delete(String id) async {
    // sleep_noise_logs는 ON DELETE CASCADE라 함께 지워집니다.
    await _client.from('sleep_records').delete().eq('id', id);
  }

  /// 자정을 넘긴 수면을 보정합니다.
  ///
  /// DB의 sleep_period_valid 제약이 `ended_at > started_at`을 요구합니다.
  /// 밤잠(오후 8시 취침 → 오전 6시 기상)은 자정을 넘기는 것이 정상이므로
  /// 기상이 취침보다 이르면 하루를 더합니다.
  /// 취침과 기상이 같은 시각이면 자정 넘김이 아닙니다.
  ///
  /// 예전에는 여기서도 하루를 더해 **24시간짜리 수면**으로 저장했습니다.
  /// 같은 화면의 미리보기는 '0시간 0분'을 보여주고 있었으니, 사용자가 본
  /// 값과 저장된 값이 정반대였습니다.
  static bool isZeroLength(DateTime startedAt, DateTime endedAt) =>
      startedAt.isAtSameMomentAs(endedAt);

  static DateTime resolveEnd(DateTime startedAt, DateTime endedAt) {
    return endedAt.isAfter(startedAt)
        ? endedAt
        : endedAt.add(const Duration(days: 1));
  }

  /// insert할 행을 만듭니다. 전송과 분리해 제약 준수를 테스트로 확인합니다.
  static Map<String, dynamic> buildRow({
    required String babyId,
    required SleepType type,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    return {
      'baby_id': babyId,
      'sleep_type': type.name,
      'started_at': toDbTime(startedAt),
      'ended_at': toDbTime(resolveEnd(startedAt, endedAt)),
    };
  }

  static Future<void> save({
    required String babyId,
    required SleepType type,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    await _client.from('sleep_records').insert(buildRow(
          babyId: babyId,
          type: type,
          startedAt: startedAt,
          endedAt: endedAt,
        ));
  }
}
