import 'package:flutter_test/flutter_test.dart';

/// dd29c21 의 NoiseTracker 에서 **스케줄링 부분만** 그대로 옮긴 것.
/// 바꾼 것은 딱 하나: 네트워크 호출을 조절 가능한 지연으로 대체.
class Probe {
  Probe({required this.checkpointInterval, required this.writeDuration});

  final Duration checkpointInterval;
  final Duration writeDuration;

  int _count = 0;
  Future<void>? _inFlight;
  DateTime? _lastCheckpoint;

  /// 실제로 쓰기가 **시작된** 시각들.
  final List<Duration> writeStarts = [];
  final List<Duration> writeEnds = [];

  late DateTime _t0;
  DateTime _now = DateTime(2026);
  void setClock(DateTime t) => _now = t;
  void start(DateTime t) {
    _t0 = t;
    _now = t;
  }

  // ---- 원본 _record 그대로 (140-146행) ----
  void record() {
    _count++;

    final now = _now;
    final last = _lastCheckpoint;
    if (last == null || now.difference(last) >= checkpointInterval) {
      _lastCheckpoint = now;
      _checkpointInBackground();
    }
  }

  // ---- 원본 149-151행 그대로 ----
  void _checkpointInBackground() {
    _inFlight ??= _writeCheckpoint().whenComplete(() => _inFlight = null);
  }

  // ---- 원본 157-171행: try/catch 로 절대 throw 하지 않는 것까지 같음 ----
  Future<void> _writeCheckpoint() async {
    final startedAt = _now.difference(_t0);
    writeStarts.add(startedAt);
    try {
      await Future<void>.delayed(writeDuration); // 느린 망
      writeEnds.add(_now.difference(_t0));
    } catch (_) {}
  }
}

void main() {
  test('느린 쓰기 중 건너뛴 주기가 _lastCheckpoint 를 소모하는가', () async {
    await fakeAsync();
  });
}

Future<void> fakeAsync() async {
  // FakeAsync 를 쓰기 위해 별도 헬퍼
}
