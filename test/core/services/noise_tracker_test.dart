import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/noise_tracker.dart';
import 'package:flutter_project/core/services/sleep_type.dart';

/// 측정이 끝났을 때 못 보낸 로그를 어떻게 처리하는지 고정합니다.
///
/// 이 테스트는 **Supabase를 초기화하지 않은 채** 돌립니다. 그러면 전송이
/// 반드시 실패하므로, 네트워크가 끊긴 상태를 따로 흉내 낼 필요 없이
/// "보내지 못한 로그가 남았을 때"를 그대로 재현할 수 있습니다.
void main() {
  /// 배치 크기(30)에 못 미치게 넣어 전송이 저절로 시작되지 않게 합니다.
  void feed(NoiseTracker tracker, int count) {
    for (var i = 0; i < count; i++) {
      tracker.onNoiseLevelChanged(42.0);
    }
  }

  test('보내지 못한 로그를 들고 있는다', () {
    // 잠깐 실패했다고 버리면 안 됩니다. 다음 배치에서 다시 시도합니다.
    final tracker = NoiseTracker();
    feed(tracker, 5);

    expect(tracker.bufferedCount, 5);
  });

  test('측정이 끝나면 못 보낸 로그를 버린다', () async {
    // 이 인스턴스는 백그라운드 서비스가 사는 동안 계속 재사용됩니다.
    // 남겨두면 다음 측정의 sleep_records 행에 딸려 들어갑니다.
    final tracker = NoiseTracker();
    tracker.beginSession(SleepType.night);
    feed(tracker, 5);

    await tracker.finish();

    expect(tracker.bufferedCount, 0);
  });

  test('지난 측정의 로그가 다음 측정으로 넘어오지 않는다', () async {
    // 넘어오면 어젯밤 소음이 오늘 낮잠 기록으로 저장되고, 그 구간의
    // 평균 소음과 판정이 함께 틀어집니다.
    final tracker = NoiseTracker();

    tracker.beginSession(SleepType.night);
    feed(tracker, 7);
    await tracker.finish();

    tracker.beginSession(SleepType.nap);
    feed(tracker, 2);

    expect(tracker.bufferedCount, 2);
  });

  test('값이 유한하지 않으면 담지 않는다', () {
    // NaN이 들어가면 insert 전체가 실패해 정상 로그까지 함께 막힙니다.
    final tracker = NoiseTracker();
    tracker.onNoiseLevelChanged(double.nan);
    tracker.onNoiseLevelChanged(double.infinity);

    expect(tracker.bufferedCount, 0);
  });
}
