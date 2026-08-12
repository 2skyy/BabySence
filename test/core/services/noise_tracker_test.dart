import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/noise_tracker.dart';
import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';

/// 소음 집계를 고정합니다.
///
/// 이 테스트는 **Supabase를 초기화하지 않은 채** 돌립니다. 그러면 저장이
/// 반드시 실패하므로, 망이 끊긴 밤을 따로 흉내 낼 필요가 없습니다. 그리고
/// 그 상태에서도 결과가 나온다는 것이 이 설계의 핵심입니다 — 예전에는
/// 로그를 서버에 넣고 서버에서 다시 읽어야 판정이 나왔고, 밤새 망이 끊기면
/// 8시간을 재고도 "측정값이 하나도 저장되지 않았습니다"로 끝났습니다.
void main() {
  /// 창을 0으로 두어 값 하나가 표본 하나가 되게 합니다.
  NoiseTracker tracker() => NoiseTracker(sampleInterval: Duration.zero);

  /// 표본이 [values.length]개가 되도록 값을 넣습니다.
  ///
  /// 값 하나는 창을 여는 데 쓰이고 다음 값이 와야 표본이 됩니다. 마지막
  /// 창은 [NoiseTracker.finish]가 닫습니다.
  void feed(NoiseTracker target, List<double> values) {
    for (final v in values) {
      target.onNoiseLevelChanged(v);
    }
  }

  test('망이 끊겨 있어도 집계가 나온다', () async {
    // 이 테스트가 도는 환경에는 Supabase가 없습니다. 저장은 전부 실패합니다.
    final t = tracker();
    t.beginSession(SleepType.night);
    feed(t, [40, 50, 60]);

    final stats = await t.finish();

    expect(stats, isNotNull);
    expect(stats!.sampleCount, 3);
  });

  test('평균과 최대가 표본과 같다', () async {
    // 측정 경로의 계산이 SleepNoiseStats.fromDecibels와 같은 식이어야
    // 합니다. 다르면 지난 밤을 다시 볼 때 숫자가 어긋납니다.
    const values = [30.0, 45.0, 60.0, 35.0];

    final t = tracker();
    t.beginSession(SleepType.night);
    feed(t, values);

    final stats = await t.finish();
    final expected = SleepNoiseStats.fromDecibels(values);

    expect(stats!.averageDb, closeTo(expected.averageDb, 0.0001));
    expect(stats.maxDb, expected.maxDb);
    expect(stats.sampleCount, expected.sampleCount);
  });

  test('마지막 창을 버리지 않는다', () async {
    // 안 그러면 짧은 측정이 통째로 0건이 됩니다.
    final t = tracker();
    t.beginSession(SleepType.night);
    t.onNoiseLevelChanged(42.0);

    final stats = await t.finish();

    expect(stats!.sampleCount, 1);
    expect(stats.maxDb, 42.0);
  });

  test('소리를 하나도 못 받으면 null', () async {
    // 0으로 채운 집계를 돌려주면 화면이 '아주 조용한 밤'으로 그립니다.
    final t = tracker();
    t.beginSession(SleepType.night);

    expect(await t.finish(), isNull);
  });

  test('지난 측정이 다음 측정으로 넘어오지 않는다', () async {
    // 이 인스턴스는 백그라운드 서비스가 사는 동안 재사용됩니다(main.dart).
    // 넘어오면 어젯밤 소음이 오늘 낮잠 집계에 섞입니다.
    final t = tracker();

    t.beginSession(SleepType.night);
    feed(t, [80, 90, 100]);
    await t.finish();

    t.beginSession(SleepType.nap);
    feed(t, [30, 30]);

    final stats = await t.finish();

    expect(stats!.sampleCount, 2);
    expect(stats.maxDb, 30.0, reason: '어젯밤 100dB가 남아 있으면 안 됩니다');
  });

  test('finish 뒤에는 표본이 비어 있다', () async {
    final t = tracker();
    t.beginSession(SleepType.night);
    feed(t, [40, 40, 40]);
    await t.finish();

    expect(t.sampleCount, 0);
  });

  group('이상한 값', () {
    test('유한하지 않은 값은 세지 않는다', () async {
      // 예전에는 insert 하나를 막는 문제였지만, 지금은 **더 나쁩니다** —
      // NaN 하나가 합을 오염시켜 밤 전체의 평균을 망칩니다.
      final t = tracker();
      t.beginSession(SleepType.night);
      t.onNoiseLevelChanged(double.nan);
      t.onNoiseLevelChanged(double.infinity);

      expect(await t.finish(), isNull);
    });

    test('NaN이 섞여도 나머지 평균이 살아남는다', () async {
      final t = tracker();
      t.beginSession(SleepType.night);
      feed(t, [40, double.nan, 60]);

      final stats = await t.finish();

      expect(stats!.sampleCount, 2);
      expect(stats.averageDb, closeTo(50.0, 0.0001));
    });

    test('범위를 벗어난 값은 잘라서 센다', () async {
      final t = tracker();
      t.beginSession(SleepType.night);
      feed(t, [-10, 500]);

      final stats = await t.finish();

      expect(stats!.maxDb, 200.0);
      expect(stats.averageDb, closeTo(100.0, 0.0001));
    });
  });

  test('집계를 isolate 사이로 실어 보낼 수 있다', () {
    // 백그라운드가 UI에 넘기는 길입니다. isolate 사이는 값만 오갑니다.
    const stats =
        SleepNoiseStats(averageDb: 41.25, maxDb: 63.5, sampleCount: 120);
    final restored = SleepNoiseStats.fromPayload(stats.toMap());

    expect(restored.averageDb, stats.averageDb);
    expect(restored.maxDb, stats.maxDb);
    expect(restored.sampleCount, stats.sampleCount);
  });
}
