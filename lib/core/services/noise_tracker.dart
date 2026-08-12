import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

import 'baby_service.dart';
import 'sleep_type.dart';

/// 측정된 소음을 모아 Supabase의 sleep_noise_logs에 배치로 저장합니다.
///
/// 측정 한 번(시작~중지)이 sleep_records 한 행이 되고, 그 아래에 로그가 쌓입니다.
/// 백그라운드 서비스 isolate에서 동작하므로, 그 isolate에서도 Supabase가
/// 초기화되어 있어야 합니다(main.dart의 onStart 참고).
class NoiseTracker {
  /// 한 행으로 묶는 시간. 테스트는 [Duration.zero]를 넣어 값마다 한 행을
  /// 만듭니다.
  final Duration sampleInterval;

  NoiseTracker({this.sampleInterval = const Duration(seconds: 1)});

  static const int _batchSize = 30;

  /// 전송에 계속 실패할 때 메모리가 무한히 늘어나지 않도록 두는 상한.
  /// 30건 배치 기준 20회분입니다.
  static const int _maxBufferedLogs = 600;

  final List<Map<String, dynamic>> _buffer = [];

  String? _sleepRecordId;

  /// 진행 중인 전송. 같은 배치를 두 번 보내지 않기 위한 것입니다.
  /// [finish]가 이걸 기다려야 마지막 배치를 놓치지 않습니다.
  Future<void>? _inFlight;

  SleepType _sleepType = SleepType.night;

  /// 아직 보내지 못한 로그 수. 측정이 끝나면 0이어야 합니다.
  @visibleForTesting
  int get bufferedCount => _buffer.length;

  /// 이번 측정이 쓰고 있는 sleep_records 행의 id. 아직 없으면 null입니다.
  ///
  /// 결과 화면이 **어느 기록의 통계를 봐야 하는지** 알려면 이 값이 필요합니다.
  /// 예전에는 화면이 '가장 최근 수면 기록'을 짐작해서 골랐는데, 그 사이에
  /// 손으로 적은 수면 기록이 들어오면 그쪽을 집었습니다.
  String? get sleepRecordId => _sleepRecordId;

  static SupabaseClient get _client => Supabase.instance.client;

  /// 측정을 시작할 때, 이번 측정이 밤잠인지 낮잠인지 알려줍니다.
  /// 첫 배치를 보낼 때 만들 sleep_records 행에 이 값이 들어갑니다.
  void beginSession(SleepType sleepType) {
    _sleepType = sleepType;
    // 지난 측정의 창이 남아 있으면 첫 행이 어제 시각으로 들어갑니다.
    _windowStart = null;
    _windowMax = 0;
  }

  /// 지금 모으는 중인 창의 시작과, 그 창에서 본 가장 큰 값.
  ///
  /// 오디오 콜백은 초당 여러 번 오는데 그대로 다 넣으면 하룻밤에 수만 행이
  /// 됩니다. 수면 환경 소음은 1초 단위면 충분합니다.
  ///
  /// 평균이 아니라 **최댓값**을 남깁니다. 아이를 깨우는 것은 평균이 아니라
  /// 순간의 큰 소리입니다. (넘어오는 값 자체가 이미 이동평균이라는 것은
  /// 별개 문제입니다 — 그건 원본 최대를 함께 저장해야 풀립니다.)
  DateTime? _windowStart;
  double _windowMax = 0;

  /// 보정이 끝난 데시벨 값을 받습니다.
  ///
  /// 값은 호출하는 쪽(main.dart의 소음 스트림)에서 이미 오프셋과 이동평균을
  /// 적용해 넘겨줍니다. 여기서 다시 보정하면 이중으로 적용되므로 손대지 않습니다.
  void onNoiseLevelChanged(double decibel) {
    if (!decibel.isFinite) return;

    // sleep_noise_logs.decibel의 CHECK 제약(0~200)을 벗어나면 insert 전체가 실패합니다.
    final bounded = decibel.clamp(0.0, 200.0);
    final now = DateTime.now();

    final start = _windowStart;
    if (start == null) {
      _windowStart = now;
      _windowMax = bounded;
      return;
    }

    if (now.difference(start) < sampleInterval) {
      if (bounded > _windowMax) _windowMax = bounded;
      return;
    }

    _record(start, _windowMax);
    _windowStart = now;
    _windowMax = bounded;
  }

  /// 모으던 창을 한 행으로 만듭니다.
  void _record(DateTime at, double decibel) {
    _buffer.add({
      'measured_at': toDbTime(at),
      'decibel': double.parse(decibel.toStringAsFixed(2)),
    });

    if (_buffer.length >= _batchSize) {
      _flushInBackground();
    }
  }

  /// 보내는 중이 아니면 전송을 시작합니다. 중이면 아무 일도 하지 않습니다.
  void _flushInBackground() {
    _inFlight ??= _flush().whenComplete(() => _inFlight = null);
  }

  /// 측정을 끝낼 때 호출합니다. 남은 버퍼를 보내고 수면 기록을 닫습니다.
  Future<void> finish() async {
    // 모으던 1초 창을 마지막 한 행으로 남깁니다. 안 그러면 짧은 측정이
    // 통째로 0건이 됩니다.
    final start = _windowStart;
    if (start != null) {
      _record(start, _windowMax);
      _windowStart = null;
      _windowMax = 0;
    }

    // 보내는 중이면 끝날 때까지 기다립니다. 기다리지 않고 닫으면 그 배치가
    // 통째로 사라집니다.
    await _inFlight;
    _flushInBackground();
    await _inFlight;

    final recordId = _sleepRecordId;
    _sleepRecordId = null;

    // 못 보낸 로그는 여기서 버립니다.
    //
    // 이 인스턴스는 백그라운드 서비스가 살아 있는 동안 계속 재사용됩니다
    // (main.dart에서 하나만 만듭니다). 남겨두면 다음 측정이 시작될 때
    // _ensureSleepRecord가 만든 **새 sleep_records 행**에 딸려 들어가,
    // 어젯밤 로그가 오늘 낮잠 기록으로 저장됩니다. 그 구간의 평균 소음이
    // 오염되고 판정까지 틀어집니다.
    if (_buffer.isNotEmpty) {
      debugPrint('소음 로그 ${_buffer.length}건을 보내지 못해 버립니다.');
      _buffer.clear();
    }

    if (recordId == null) return;

    try {
      await _client
          .from('sleep_records')
          .update({'ended_at': toDbTime(DateTime.now())})
          .eq('id', recordId);
    } catch (e) {
      debugPrint('수면 기록 종료 시각 저장 실패: $e');
    }
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;

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
          'started_at': toDbTime(DateTime.now()),
        })
        .select()
        .single();

    return _sleepRecordId = row['id'] as String;
  }
}
