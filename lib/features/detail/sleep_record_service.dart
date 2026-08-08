import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// 로그 행들에서 통계를 계산합니다.
  ///
  /// 집계를 앱에서 하는 이유: Supabase REST로는 avg/max 집계를 바로 쓸 수 없고,
  /// 한 수면 구간의 로그는 많아도 수천 건이라 클라이언트에서 계산해도 충분합니다.
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
  static Future<SleepNoiseStats> loadNoiseStats(String sleepRecordId) async {
    final rows = await _client
        .from('sleep_noise_logs')
        .select('decibel')
        .eq('sleep_record_id', sleepRecordId);

    return SleepNoiseStats.fromDecibels([
      for (final row in rows) (row['decibel'] as num).toDouble(),
    ]);
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
      'started_at': startedAt.toIso8601String(),
      'ended_at': resolveEnd(startedAt, endedAt).toIso8601String(),
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
