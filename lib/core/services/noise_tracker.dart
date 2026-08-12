import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';
import '../../features/detail/sleep_record_service.dart';

import 'baby_service.dart';
import 'sleep_type.dart';

/// 측정된 소음을 **메모리에서 집계**해 sleep_records 한 행에 적습니다.
///
/// 예전에는 1초마다 한 행씩 `sleep_noise_logs`에 쌓았습니다. 하룻밤이면
/// 28,800행이고, 그것을 서버까지 나르려고 배치·재시도·버퍼 상한·중복 전송
/// 방지가 붙었습니다. 그런데 그 로그를 읽는 곳은 평균·최대를 구하는 집계
/// 하나뿐이었고, 그래프 화면은 만든 적이 없습니다. **원본을 붙들고 있던
/// 이유가 없었고, 그 원본을 나르는 장치들이 이 기능의 결함을 만들었습니다.**
///
/// 지금은 세 숫자(합·최대·개수)만 들고 있다가 [checkpointInterval]마다 한 행을
/// 갱신합니다. 판정 경로에서 네트워크가 통째로 빠지고, 밤새 망이 끊겨도
/// 결과는 나옵니다.
///
/// **왜 끝에 한 번만 쓰지 않는가**: 이 인스턴스는 백그라운드 isolate에
/// 있습니다. 8시간치를 메모리에만 들고 있으면 OS가 서비스를 죽이는 순간
/// 밤 전체가 없던 일이 됩니다. 주기적으로 찍으면 잃는 것이
/// [checkpointInterval]로 줄어듭니다.
///
/// 백그라운드 서비스 isolate에서 동작하므로, 그 isolate에서도 Supabase가
/// 초기화되어 있어야 합니다(main.dart의 onStart 참고).
class NoiseTracker {
  /// 한 표본으로 묶는 시간. 테스트는 [Duration.zero]를 넣어 값마다 한 표본을
  /// 만듭니다.
  final Duration sampleInterval;

  /// 집계를 sleep_records에 적어 두는 주기.
  ///
  /// 이 값이 곧 **서비스가 죽었을 때 잃는 시간**입니다. 짧게 하면 쓰기가
  /// 잦아지고, 길게 하면 잃는 것이 늘어납니다.
  final Duration checkpointInterval;

  NoiseTracker({
    this.sampleInterval = const Duration(seconds: 1),
    this.checkpointInterval = const Duration(seconds: 60),
  });

  /// 지금까지의 합·최대·개수. 표본은 1초 창의 최댓값입니다.
  double _sum = 0;
  double _max = 0;
  int _count = 0;

  String? _sleepRecordId;

  /// 진행 중인 쓰기. 같은 순간에 두 번 쓰지 않기 위한 것입니다.
  Future<void>? _inFlight;

  /// 마지막으로 쓰기를 **시도한** 시각. 성공 여부와 무관하게 갱신합니다.
  /// 실패할 때마다 다시 시도하면 망이 끊긴 밤에 초당 한 번씩 두드립니다.
  DateTime? _lastCheckpoint;

  SleepType _sleepType = SleepType.night;

  /// 이번 측정이 쓰고 있는 sleep_records 행의 id. 아직 없으면 null입니다.
  ///
  /// 결과 화면이 **어느 기록을 봐야 하는지** 알려면 이 값이 필요합니다.
  /// 예전에는 화면이 '가장 최근 수면 기록'을 짐작해서 골랐는데, 그 사이에
  /// 손으로 적은 수면 기록이 들어오면 그쪽을 집었습니다.
  String? get sleepRecordId => _sleepRecordId;

  /// 지금까지 모은 표본 수. 측정이 끝나면 0으로 돌아갑니다.
  @visibleForTesting
  int get sampleCount => _count;

  static SupabaseClient get _client => Supabase.instance.client;

  /// 측정을 시작할 때, 이번 측정이 밤잠인지 낮잠인지 알려줍니다.
  void beginSession(SleepType sleepType) {
    _sleepType = sleepType;
    _reset();
  }

  void _reset() {
    // 지난 측정의 창이 남아 있으면 첫 표본이 어제 값과 섞입니다.
    _windowStart = null;
    _windowMax = 0;
    _sum = 0;
    _max = 0;
    _count = 0;
    _lastCheckpoint = null;
    _sleepRecordId = null;
  }

  /// 지금 모으는 중인 창의 시작과, 그 창에서 본 가장 큰 값.
  ///
  /// 오디오 콜백은 초당 여러 번 오는데 그대로 다 더하면 콜백이 잦은 기기일수록
  /// 평균이 그쪽으로 쏠립니다. 창을 두면 기기와 무관하게 초당 한 표본입니다.
  ///
  /// 평균이 아니라 **최댓값**을 남깁니다. 아이를 깨우는 것은 평균이 아니라
  /// 순간의 큰 소리입니다. (넘어오는 값 자체가 이미 이동평균이라는 것은
  /// 별개 문제입니다 — docs/remaining-work.md의 B.)
  DateTime? _windowStart;
  double _windowMax = 0;

  /// 보정이 끝난 데시벨 값을 받습니다.
  ///
  /// 값은 호출하는 쪽(main.dart의 소음 스트림)에서 이미 오프셋과 이동평균을
  /// 적용해 넘겨줍니다. 여기서 다시 보정하면 이중으로 적용되므로 손대지 않습니다.
  void onNoiseLevelChanged(double decibel) {
    if (!decibel.isFinite) return;

    // 범위를 벗어난 값은 잘라서 씁니다.
    //
    // 예전에는 DB의 CHECK 제약(0~200) 때문이었지만, 지금은 **더 중요합니다.**
    // 그때는 이상한 값 하나가 배치 하나를 막았지만, 지금은 [_sum]을 오염시켜
    // 밤 전체의 평균을 망칩니다.
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

    _record(_windowMax);
    _windowStart = now;
    _windowMax = bounded;
  }

  /// 창 하나를 집계에 반영하고, 주기가 됐으면 저장을 시작합니다.
  void _record(double decibel) {
    _sum += decibel;
    if (decibel > _max) _max = decibel;
    _count++;

    final now = DateTime.now();
    final last = _lastCheckpoint;
    if (last == null || now.difference(last) >= checkpointInterval) {
      _lastCheckpoint = now;
      _checkpointInBackground();
    }
  }

  /// 쓰는 중이 아니면 저장을 시작합니다. 중이면 아무 일도 하지 않습니다.
  void _checkpointInBackground() {
    _inFlight ??= _writeCheckpoint().whenComplete(() => _inFlight = null);
  }

  /// 지금까지의 집계를 sleep_records 행에 적습니다.
  ///
  /// 행이 없으면 만듭니다. 만들기에 실패하면 다음 주기에 다시 해 봅니다 —
  /// 재시도 대상이 로그 30건 배열이 아니라 **행 하나**라 단순합니다.
  Future<void> _writeCheckpoint({DateTime? endedAt}) async {
    if (_count == 0 && endedAt == null) return;

    try {
      final recordId = await _ensureSleepRecord();
      await _client.from('sleep_records').update({
        'average_db': _rounded(_count == 0 ? 0 : _sum / _count),
        'max_db': _rounded(_max),
        'sample_count': _count,
        if (endedAt != null) 'ended_at': toDbTime(endedAt),
      }).eq('id', recordId);
    } catch (e) {
      debugPrint('소음 집계 저장 실패(다음 주기에 재시도): $e');
    }
  }

  /// numeric(5,2) 컬럼에 맞춥니다.
  static double _rounded(double value) =>
      double.parse(value.toStringAsFixed(2));

  /// 측정을 끝냅니다. 이번 밤의 집계를 돌려주고 수면 기록을 닫습니다.
  ///
  /// **돌려주는 값이 결과 화면이 쓰는 값입니다.** 예전에는 화면이 저장이
  /// 끝나기를 고정 2초 기다렸다가 서버에서 다시 읽었는데, 느린 망에서는 그
  /// 안에 안 끝나 "저장하지 못했습니다"가 떴습니다. 실제로는 조금만 더
  /// 기다리면 됐을 때가 있었습니다.
  ///
  /// 표본이 하나도 없으면 null입니다.
  Future<SleepNoiseStats?> finish() async {
    // 모으던 창을 마지막 표본으로 남깁니다. 안 그러면 짧은 측정이 통째로
    // 0건이 됩니다.
    final start = _windowStart;
    if (start != null) {
      _sum += _windowMax;
      if (_windowMax > _max) _max = _windowMax;
      _count++;
      _windowStart = null;
      _windowMax = 0;
    }

    // 쓰는 중이면 끝날 때까지 기다립니다.
    await _inFlight;

    final stats = _count == 0
        ? null
        : SleepNoiseStats(
            averageDb: _sum / _count,
            maxDb: _max,
            sampleCount: _count,
          );

    // 마지막 집계와 종료 시각을 함께 적습니다.
    if (_sleepRecordId != null || _count > 0) {
      await _writeCheckpoint(endedAt: DateTime.now());
    }

    // 이 인스턴스는 백그라운드 서비스가 사는 동안 재사용됩니다
    // (main.dart에서 하나만 만듭니다). 비우지 않으면 어젯밤 집계가 오늘
    // 낮잠에 딸려 들어갑니다.
    _reset();

    return stats;
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
