import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';
import '../../features/detail/sleep_record_service.dart';

import 'baby_service.dart';
import 'sleep_type.dart';

/// 측정이 끝났을 때 돌려주는 것.
class NoiseSessionResult {
  /// 이번 측정의 집계. 소리를 하나도 못 받았으면 null입니다.
  final SleepNoiseStats? stats;

  /// 이번 측정이 쓴 sleep_records 행의 id. 만들지 못했으면 null입니다.
  final String? recordId;

  /// 수면 기록을 제대로 닫았는지.
  ///
  /// **판정과는 별개입니다.** 집계는 메모리에서 나오므로 이 값이 false여도
  /// 결과는 보여줄 수 있습니다. 다만 "저장까지 됐다"고 말하면 안 됩니다 —
  /// 실패를 성공으로 보여주지 않는 것이 이 프로젝트의 원칙입니다.
  final bool saved;

  const NoiseSessionResult({
    required this.stats,
    required this.recordId,
    required this.saved,
  });
}

/// 측정된 소음을 **메모리에서만 집계**합니다.
///
/// 예전에는 1초마다 한 행씩 `sleep_noise_logs`에 쌓았습니다. 하룻밤이면
/// 28,800행이고, 그것을 서버까지 나르려고 배치·재시도·버퍼 상한·중복 전송
/// 방지가 붙었습니다. 그런데 그 로그를 읽는 곳은 평균·최대를 구하는 집계
/// 하나뿐이었고, 그래프 화면은 만든 적이 없습니다. **원본을 붙들고 있던
/// 이유가 없었고, 그 원본을 나르는 장치들이 이 기능의 결함을 만들었습니다.**
///
/// **소음 수치는 이제 어디에도 따로 저장하지 않습니다.** 화면에는 실시간으로
/// 보여주고(`main.dart`의 `update_db`), 측정이 끝나면 [finish]가 집계를
/// 돌려줍니다. 그 숫자가 남는 곳은 판정 한 행뿐입니다 —
/// `assessments.inputs`에 `average_db`·`max_db`·`sample_count`가 들어가고,
/// 분석 화면이 그것을 읽습니다. 같은 숫자를 `sleep_records`에도 적어 두었다가
/// 중복이라 걷어냈습니다(011).
///
/// 이 표가 여전히 만드는 것은 **수면 기록 자체**입니다 — 밤잠인지 낮잠인지,
/// 언제 시작해 언제 끝났는지. 그건 기록 탭에 뜨는 별개 기능입니다.
///
/// 백그라운드 서비스 isolate에서 동작하므로, 그 isolate에서도 Supabase가
/// 초기화되어 있어야 합니다(main.dart의 onStart 참고).
class NoiseTracker {
  /// 한 표본으로 묶는 시간. 테스트는 [Duration.zero]를 넣어 값마다 한 표본을
  /// 만듭니다.
  final Duration sampleInterval;

  /// 수면 기록 행 만들기에 실패했을 때 다시 해 보는 간격.
  ///
  /// 실패할 때마다 곧바로 다시 하면 망이 끊긴 밤에 초당 한 번씩 두드립니다.
  final Duration retryInterval;

  NoiseTracker({
    this.sampleInterval = const Duration(seconds: 1),
    this.retryInterval = const Duration(seconds: 60),
  });

  /// 지금까지의 합·개수. 표본은 1초 창의 최댓값입니다.
  double _sum = 0;
  int _count = 0;

  /// 이번 측정에서 **가장 컸던 순간**.
  ///
  /// 평균과 달리 평활(이동평균)을 **거치지 않은** 값에서 셉니다. 화면이
  /// "가장 컸던 소리는 …dB"라고 말하는 값이고, WHO의 LAmax에 대응합니다.
  ///
  /// 평활된 값에서 세면 순간 소리를 놓칩니다 — 이전 85% + 새 값 15%라,
  /// 배경 40dB에서 90dB가 한 번 들어와도 45.25dB까지만 올라갑니다.
  /// 아이를 깨우는 것은 평균이 아니라 그 순간의 큰 소리입니다.
  double _peak = 0;

  String? _sleepRecordId;

  /// 저장 한 번에 허용하는 시간.
  ///
  /// **화면이 기다리는 시간보다 짧아야 합니다.** 화면은 종료 신호를 15초까지
  /// 기다립니다. 여기에 상한이 없으면 TCP는 붙어 있는데 응답이 안 오는 망
  /// (지하, 캡티브 포털)에서 몇 분을 멎고, 그 사이 화면은 먼저 포기해
  /// "끝맺지 못했습니다"로 돌아섭니다 — 집계는 메모리에 멀쩡히 있는데.
  static const Duration _saveTimeout = Duration(seconds: 8);

  /// 진행 중인 쓰기. 같은 순간에 두 번 쓰지 않기 위한 것입니다.
  Future<void>? _inFlight;

  /// 진행 중인 마무리. **끝맺는 길이 둘이라 겹칠 수 있습니다** —
  /// 중지를 누른 직후 '완전히 끄기'를 누르면 그렇습니다. 막지 않으면 같은
  /// 집계로 행이 두 번 만들어지고, 한 행은 종료 시각 없이 남아 기록 목록에
  /// 영영 '측정 중'으로 보입니다.
  Future<NoiseSessionResult>? _finishing;

  /// 세션 일련번호.
  ///
  /// 시간 상한은 요청을 **취소하지 않습니다.** 늦게 돌아온 insert가 다음
  /// 세션의 행 id를 어젯밤 것으로 채우면, 오늘 낮잠의 종료 시각이 어젯밤
  /// 행에 찍힙니다.
  int _session = 0;

  /// 마지막으로 행 만들기를 **시도한** 시각. 성공 여부와 무관하게 갱신합니다.
  DateTime? _lastAttempt;

  SleepType _sleepType = SleepType.night;

  /// 측정을 시작한 시각.
  ///
  /// **행을 만든 시각이 아닙니다.** 시작할 때 망이 없으면 행은 몇 분 뒤에
  /// 생기는데, 그때 `now()`를 쓰면 그 밤의 `started_at`이 실제보다 늦습니다.
  /// 심하면 insert와 종료가 몇 ms 차이로 이어져 표본은 28,800개인데 수면
  /// 길이는 0분인 행이 남습니다.
  DateTime? _startedAt;

  /// 지금까지 모은 표본 수. 측정이 끝나면 0으로 돌아갑니다.
  @visibleForTesting
  int get sampleCount => _count;

  static SupabaseClient get _client => Supabase.instance.client;

  /// 측정을 시작할 때, 이번 측정이 밤잠인지 낮잠인지 알려줍니다.
  void beginSession(SleepType sleepType) {
    _sleepType = sleepType;
    _reset();
    _session++;
    _startedAt = DateTime.now();
  }

  void _reset() {
    // 지난 측정의 창이 남아 있으면 첫 표본이 어제 값과 섞입니다.
    _windowStart = null;
    _windowMax = 0;
    _sum = 0;
    _peak = 0;
    _count = 0;
    _lastAttempt = null;
    _startedAt = null;
    _sleepRecordId = null;
  }

  /// 지금 모으는 중인 창의 시작과, 그 창에서 본 가장 큰 값.
  ///
  /// 오디오 콜백은 초당 여러 번 오는데 그대로 다 더하면 콜백이 잦은 기기일수록
  /// 평균이 그쪽으로 쏠립니다. 창을 두면 기기와 무관하게 초당 한 표본입니다.
  ///
  /// 창 안에서는 평균이 아니라 **최댓값**을 남깁니다. 콜백이 잦은 기기에서
  /// 조용한 순간이 표본을 채워 평균을 끌어내리는 것을 막으려는 것입니다.
  /// (가장 컸던 순간은 이 창과 무관하게 [_peak]이 따로 셉니다.)
  DateTime? _windowStart;
  double _windowMax = 0;

  /// 보정이 끝난 데시벨 값을 받습니다.
  ///
  /// 값은 호출하는 쪽(main.dart의 소음 스트림)에서 이미 오프셋을 적용해
  /// 넘겨줍니다. 여기서 다시 보정하면 이중으로 적용되므로 손대지 않습니다.
  ///
  /// [decibel]은 **평활을 거친** 값입니다(이전 85% + 새 값 15%). 평균은
  /// 이 값으로 냅니다 — 지속되는 배경 소음 수준을 보려는 것이라 널뛰기를
  /// 눌러 주는 편이 맞습니다.
  ///
  /// [peak]은 **평활 전** 값입니다. 가장 컸던 순간은 여기서 셉니다. 안 주면
  /// [decibel]을 씁니다(테스트처럼 둘이 같은 경우).
  void onNoiseLevelChanged(double decibel, {double? peak}) {
    if (!decibel.isFinite) return;

    // 순간 최댓값은 창과 무관합니다 — 최댓값의 최댓값은 그냥 최댓값입니다.
    final raw = peak ?? decibel;
    if (raw.isFinite) {
      final boundedRaw = raw.clamp(0.0, 200.0);
      if (boundedRaw > _peak) _peak = boundedRaw;
    }

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

  /// 창 하나를 집계에 반영합니다.
  ///
  /// **저장하지 않습니다.** 소음 수치는 메모리에만 있습니다. 다만 수면 기록
  /// 행은 일찍 만들어 둡니다 — 재우는 동안 기록 탭에 '측정 중'으로 보이고,
  /// 끝날 때 그 행에 종료 시각만 적으면 되기 때문입니다.
  void _record(double decibel) {
    _sum += decibel;
    _count++;

    if (_sleepRecordId != null) return;

    // 만들기에 실패했으면 잠시 뒤에 다시 해 봅니다. 실패할 때마다 곧바로
    // 다시 하면 망이 끊긴 밤에 초당 한 번씩 두드립니다.
    // 앞 시도가 아직 도는 중이면 이번 주기는 건너뜁니다. `_inFlight ??=`만
    // 두면 시각만 찍히고 아무 일도 안 해 그 기회가 버려집니다.
    final now = DateTime.now();
    final last = _lastAttempt;
    if (_inFlight == null &&
        (last == null || now.difference(last) >= retryInterval)) {
      _lastAttempt = now;
      // **정말로 Future<void>여야 합니다.** `.catchError`로 String을 돌려주면
      // 정적 타입만 void이고 런타임 타입은 Future<String>이라, 나중에
      // `.timeout(onTimeout: () {})`을 붙일 때 타입이 안 맞아 터집니다.
      _inFlight = _tryEnsureSleepRecord()
          .whenComplete(() => _inFlight = null);
    }
  }

  /// 측정을 끝냅니다. 집계와 기록 id, 저장 성공 여부를 함께 돌려줍니다.
  ///
  /// **집계는 메모리에서 나옵니다.** 그래서 망이 끊겨 있어도 결과가 나옵니다.
  /// 예전에는 로그를 서버에 넣고 서버에서 다시 읽어야 판정이 나왔고, 밤새
  /// 망이 끊기면 8시간을 재고도 결과가 없었습니다.
  ///
  /// [NoiseSessionResult.saved]는 **수면 기록을 닫았는지**입니다. 판정과는
  /// 별개이며, false여도 결과는 보여줄 수 있습니다. 다만 저장까지 됐다고
  /// 말하면 안 됩니다.
  Future<NoiseSessionResult> finish() =>
      _finishing ??= _finishOnce().whenComplete(() => _finishing = null);

  Future<NoiseSessionResult> _finishOnce() async {
    // 모으던 창을 마지막 표본으로 남깁니다. 안 그러면 짧은 측정이 통째로
    // 0건이 됩니다.
    if (_windowStart != null) {
      _sum += _windowMax;
      _count++;
      _windowStart = null;
      _windowMax = 0;
    }

    // 행을 만드는 중이면 끝날 때까지 기다립니다. 기다리지 않으면 방금 만든
    // 행의 id를 놓칩니다. 다만 영영 기다리지는 않습니다.
    await _inFlight?.timeout(_saveTimeout, onTimeout: () {});

    final stats = _count == 0
        ? null
        : SleepNoiseStats(
            averageDb: _sum / _count,
            maxDb: _peak,
            sampleCount: _count,
          );

    // 표본이 하나도 없으면 수면 기록도 남기지 않습니다.
    var saved = false;
    String? recordId = _sleepRecordId;
    if (stats != null) {
      try {
        recordId = await _ensureSleepRecord().timeout(_saveTimeout);
        await _client
            .from('sleep_records')
            .update({'ended_at': toDbTime(DateTime.now())})
            .eq('id', recordId)
            .timeout(_saveTimeout);
        saved = true;
      } catch (e) {
        // 삼키지 않습니다. 화면이 "저장하지 못했다"고 말할 수 있어야 합니다.
        debugPrint('수면 기록 종료 저장 실패: $e');
      }
    }

    // 이 인스턴스는 백그라운드 서비스가 사는 동안 재사용됩니다
    // (main.dart에서 하나만 만듭니다). 비우지 않으면 어젯밤 집계가 오늘
    // 낮잠에 딸려 들어갑니다.
    _reset();

    return NoiseSessionResult(stats: stats, recordId: recordId, saved: saved);
  }

  /// 행 만들기를 한 번 해 봅니다. 실패는 삼킵니다 — 재는 도중이라 알릴
  /// 곳이 없고, 다음 주기에 다시 합니다. 끝낼 때 또 실패하면 그때는
  /// [NoiseSessionResult.saved]로 화면에 전해집니다.
  Future<void> _tryEnsureSleepRecord() async {
    try {
      await _ensureSleepRecord();
    } catch (e) {
      debugPrint('수면 기록 생성 실패(잠시 뒤 재시도): $e');
    }
  }

  /// 이번 측정에 대응하는 sleep_records 행을 만들고 id를 돌려줍니다.
  Future<String> _ensureSleepRecord() async {
    final existing = _sleepRecordId;
    if (existing != null) return existing;

    // 이 요청이 어느 세션의 것인지 붙잡아 둡니다. 상한에 걸려 포기한 뒤에도
    // 요청 자체는 계속 살아 있어, 늦게 돌아왔을 때 다음 세션의 id를 어젯밤
    // 것으로 덮을 수 있습니다.
    final session = _session;

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
          // 행을 만든 시각이 아니라 **측정을 시작한** 시각입니다.
          'started_at': toDbTime(_startedAt ?? DateTime.now()),
        })
        .select()
        .single();

    final id = row['id'] as String;
    if (session == _session) _sleepRecordId = id;
    return id;
  }
}
