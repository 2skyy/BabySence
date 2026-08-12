import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/noise_tracker.dart';
import 'package:flutter_project/core/services/sleep_type.dart';

void main() {
  test('probe: finish()를 겹쳐 부르면 두 번째가 살아 있는 상태를 다시 본다', () async {
    final t = NoiseTracker(sampleInterval: Duration.zero);
    t.beginSession(SleepType.night);
    for (final v in [40.0, 50.0, 60.0]) {
      t.onNoiseLevelChanged(v);
    }

    // #1을 await하지 않고 던져 둔 채(main.dart의 stopNoiseMeasurement)
    // #2를 부릅니다(stopService).
    final f1 = t.finish();
    final f2 = t.finish();

    final r1 = await f1;
    final r2 = await f2;

    // ignore: avoid_print
    print('r1.stats=${r1.stats?.sampleCount} r2.stats=${r2.stats?.sampleCount}');
    // ignore: avoid_print
    print('r1.avg=${r1.stats?.averageDb} r2.avg=${r2.stats?.averageDb}');

    // 두 번째가 null이면 방어가 있는 것, non-null이면 같은 집계를 두 번
    // 만들어 각자 쓰기를 시작한 것입니다.
    expect(r2.stats, isNull,
        reason: '두 번째 finish가 집계를 다시 만들면 쓰기도 다시 나갑니다');
  });

  test('probe: await로 순서를 지키면 두 번째는 빈손이다', () async {
    final t = NoiseTracker(sampleInterval: Duration.zero);
    t.beginSession(SleepType.night);
    for (final v in [40.0, 50.0, 60.0]) {
      t.onNoiseLevelChanged(v);
    }

    final r1 = await t.finish();
    final r2 = await t.finish();

    // ignore: avoid_print
    print('순차: r1=${r1.stats?.sampleCount} r2=${r2.stats?.sampleCount}');
    expect(r1.stats, isNotNull);
    expect(r2.stats, isNull);
  });
}
