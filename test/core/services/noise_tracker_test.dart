import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/noise_tracker.dart';
import 'package:flutter_project/core/services/sleep_type.dart';

/// 측정이 끝났을 때 못 보낸 로그를 어떻게 처리하는지 고정합니다.
///
/// 이 테스트는 **Supabase를 초기화하지 않은 채** 돌립니다. 그러면 전송이
/// 반드시 실패하므로, 네트워크가 끊긴 상태를 따로 흉내 낼 필요 없이
/// "보내지 못한 로그가 남았을 때"를 그대로 재현할 수 있습니다.
void main() {
  /// 실제로는 1초 창의 최댓값 하나만 남기지만, 여기서는 창을 0으로 두어
  /// 값 하나가 행 하나가 되게 합니다. 버퍼 동작만 보려는 테스트입니다.
  NoiseTracker tracker() => NoiseTracker(sampleInterval: Duration.zero);

  /// 버퍼에 [count]행이 들어가도록 값을 넣습니다.
  ///
  /// 값 하나는 창을 여는 데 쓰이고 다음 값이 와야 행이 됩니다. 그래서 한 번
  /// 더 넣어 마지막 창을 닫습니다. 배치 크기(30)에는 못 미치게 두어 전송이
  /// 저절로 시작되지 않게 합니다.
  void feed(NoiseTracker target, int count) {
    for (var i = 0; i <= count; i++) {
      target.onNoiseLevelChanged(42.0);
    }
  }

  test('보내지 못한 로그를 들고 있는다', () {
    // 잠깐 실패했다고 버리면 안 됩니다. 다음 배치에서 다시 시도합니다.
    final t = tracker();
    feed(t, 5);

    expect(t.bufferedCount, 5);
  });

  test('측정이 끝나면 못 보낸 로그를 버린다', () async {
    // 이 인스턴스는 백그라운드 서비스가 사는 동안 계속 재사용됩니다.
    // 남겨두면 다음 측정의 sleep_records 행에 딸려 들어갑니다.
    final t = tracker();
    t.beginSession(SleepType.night);
    feed(t, 5);

    await t.finish();

    expect(t.bufferedCount, 0);
  });

  test('지난 측정의 로그가 다음 측정으로 넘어오지 않는다', () async {
    // 넘어오면 어젯밤 소음이 오늘 낮잠 기록으로 저장되고, 그 구간의
    // 평균 소음과 판정이 함께 틀어집니다.
    final t = tracker();

    t.beginSession(SleepType.night);
    feed(t, 7);
    await t.finish();

    t.beginSession(SleepType.nap);
    feed(t, 2);

    expect(t.bufferedCount, 2);
  });

  test('값이 유한하지 않으면 담지 않는다', () {
    // NaN이 들어가면 insert 전체가 실패해 정상 로그까지 함께 막힙니다.
    final t = tracker();
    t.onNoiseLevelChanged(double.nan);
    t.onNoiseLevelChanged(double.infinity);

    expect(t.bufferedCount, 0);
  });
}
