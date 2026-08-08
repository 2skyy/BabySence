import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'baby_service.dart';
import 'sleep_type.dart';

/// 측정된 소음을 모아 Supabase의 sleep_noise_logs에 배치로 저장합니다.
///
/// 측정 한 번(시작~중지)이 sleep_records 한 행이 되고, 그 아래에 로그가 쌓입니다.
/// 백그라운드 서비스 isolate에서 동작하므로, 그 isolate에서도 Supabase가
/// 초기화되어 있어야 합니다(main.dart의 onStart 참고).
class NoiseTracker {
  static const int _batchSize = 30;

  /// 전송에 계속 실패할 때 메모리가 무한히 늘어나지 않도록 두는 상한.
  /// 30건 배치 기준 20회분입니다.
  static const int _maxBufferedLogs = 600;

  final List<Map<String, dynamic>> _buffer = [];

  String? _sleepRecordId;
  bool _sending = false;
  SleepType _sleepType = SleepType.night;

  static SupabaseClient get _client => Supabase.instance.client;

  /// 측정을 시작할 때, 이번 측정이 밤잠인지 낮잠인지 알려줍니다.
  /// 첫 배치를 보낼 때 만들 sleep_records 행에 이 값이 들어갑니다.
  void beginSession(SleepType sleepType) {
    _sleepType = sleepType;
  }

  /// 보정이 끝난 데시벨 값을 받습니다.
  ///
  /// 값은 호출하는 쪽(main.dart의 소음 스트림)에서 이미 오프셋과 이동평균을
  /// 적용해 넘겨줍니다. 여기서 다시 보정하면 이중으로 적용되므로 손대지 않습니다.
  void onNoiseLevelChanged(double decibel) {
    if (!decibel.isFinite) return;

    // sleep_noise_logs.decibel의 CHECK 제약(0~200)을 벗어나면 insert 전체가 실패합니다.
    final bounded = decibel.clamp(0.0, 200.0);

    _buffer.add({
      'measured_at': DateTime.now().toIso8601String(),
      'decibel': double.parse(bounded.toStringAsFixed(2)),
    });

    if (_buffer.length >= _batchSize) {
      _flush();
    }
  }

  /// 측정을 끝낼 때 호출합니다. 남은 버퍼를 보내고 수면 기록을 닫습니다.
  Future<void> finish() async {
    await _flush();

    final recordId = _sleepRecordId;
    if (recordId == null) return;

    try {
      await _client
          .from('sleep_records')
          .update({'ended_at': DateTime.now().toIso8601String()})
          .eq('id', recordId);
    } catch (e) {
      debugPrint('수면 기록 종료 시각 저장 실패: $e');
    }
    _sleepRecordId = null;
  }

  Future<void> _flush() async {
    if (_sending || _buffer.isEmpty) return;
    _sending = true;

    // 전송 중에도 스트림이 계속 값을 넣으므로, 지금 시점의 길이만 대상으로 삼습니다.
    final int count = _buffer.length;
    final batch = _buffer.take(count).toList();

    try {
      final recordId = await _ensureSleepRecord();

      await _client.from('sleep_noise_logs').insert([
        for (final log in batch) {...log, 'sleep_record_id': recordId},
      ]);

      // 성공했을 때만 비웁니다. 실패하면 남겨두고 다음 배치에서 다시 시도합니다.
      _buffer.removeRange(0, count);
      debugPrint('소음 로그 $count건 저장 완료');
    } catch (e) {
      debugPrint('소음 로그 저장 실패(다음 배치에서 재시도): $e');

      // 오래 실패하면 가장 오래된 것부터 버립니다.
      if (_buffer.length > _maxBufferedLogs) {
        _buffer.removeRange(0, _buffer.length - _maxBufferedLogs);
      }
    } finally {
      _sending = false;
    }
  }

  /// 이번 측정에 대응하는 sleep_records 행을 만들고 id를 돌려줍니다.
  Future<String> _ensureSleepRecord() async {
    final existing = _sleepRecordId;
    if (existing != null) return existing;

    final baby = await BabyService.loadCurrent();
    if (baby == null) {
      throw StateError('등록된 아이가 없어 소음을 저장할 수 없습니다.');
    }

    final row = await _client
        .from('sleep_records')
        .insert({
          'baby_id': baby.id,
          // enum 이름이 곧 DB가 받는 값입니다(night / nap).
          'sleep_type': _sleepType.name,
          'started_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return _sleepRecordId = row['id'] as String;
  }
}
