import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/noise_tracker.dart' show SleepType;

/// sleep_records 테이블 접근 (수동 입력용).
///
/// 소음 측정 중에 만들어지는 수면 기록은 [NoiseTracker]가 직접 다룹니다.
/// 이 서비스는 사용자가 시각을 직접 입력해 남기는 경우를 담당합니다.
class SleepRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

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
