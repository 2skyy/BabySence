import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// ★ 백색소음 선택 페이지 및 싱글톤 서비스 import
import './white_noise_page.dart';
import './white_noise_service.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/background_auth.dart';
import '../../core/services/sleep_type.dart';
import 'assessment/assessment_service.dart';
import 'assessment/noise_rules.dart';
import 'noise_result_page.dart';
import 'sleep_record_service.dart';

class NoiseTestPage extends StatefulWidget {
  const NoiseTestPage({super.key});

  @override
  State<NoiseTestPage> createState() => _NoiseTestPageState();
}

class _NoiseTestPageState extends State<NoiseTestPage> {
  double _currentDecibel = 0.0; // 실시간 데시벨 수치 저장
  bool _isNoiseMeasuring = false;
  StreamSubscription? _serviceSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _sessionSubscription;

  /// 시작 신호에 대한 서비스의 응답을 기다리는 곳.
  Completer<bool>? _startAck;

  /// 측정을 시작하는 중인지. 서비스 응답을 기다리는 동안 버튼을 잠급니다.
  bool _starting = false;

  /// 이번 측정을 어떤 수면으로 기록할지. 측정 중에는 바꿀 수 없습니다
  /// (sleep_records 행이 이미 만들어진 뒤라 값만 바뀌면 어긋납니다).
  SleepType _sleepType = SleepType.night;

  // 백색소음 상태 관리를 위한 싱글톤 서비스
  final WhiteNoiseService _noiseService = WhiteNoiseService();

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _listenToBackgroundService();
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _stateSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _checkInitialStatus() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) return;

    // 서비스가 켜져 있어도 백색소음만 재생 중이거나, 앱이 죽은 뒤 서비스만
    // 되살아나 아무것도 측정하지 않는 상태일 수 있습니다. 켜짐 여부로 판단하면
    // 측정하지도 않는데 '측정 중지'로 보입니다. 서비스에 직접 묻고, 답이 오면
    // noise_state 리스너가 화면을 맞춥니다.
    //
    // 되살아나는 중이면 아직 답할 준비가 안 됐을 수 있어 몇 번 더 묻습니다.
    for (var i = 0; i < 3; i++) {
      if (!mounted) return;
      service.invoke('queryNoiseState');
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();

    _serviceSubscription = service.on('update_db').listen((event) {
      if (event != null && event['db'] != null) {
        setState(() {
          _currentDecibel = double.parse(event['db'].toString());
        });
      }
    });

    // 측정 여부는 서비스가 알려주는 값만 믿습니다.
    _stateSubscription = service.on('noise_state').listen((event) {
      final measuring = event?['measuring'] == true;

      if (measuring && !(_startAck?.isCompleted ?? true)) {
        _startAck!.complete(true);
      }

      if (!mounted) return;
      setState(() => _isNoiseMeasuring = measuring);
    });

    // 방금 끝난 측정의 **집계 자체**를 받습니다.
    //
    // 예전에는 id만 받고 화면이 고정 2초를 기다렸다가 서버에서 다시 읽었는데,
    // 느린 망에서는 그 안에 저장이 안 끝나 "저장하지 못했습니다"가 떴습니다.
    // 실제로는 조금만 더 기다리면 됐을 때가 있었습니다. 지금은 백그라운드가
    // 메모리에서 집계하므로 숫자를 그대로 넘겨받습니다 — 기다릴 것도 다시
    // 읽을 것도 없고, 밤새 망이 끊겨 있었어도 결과는 나옵니다.
    _sessionSubscription = service.on('noise_session_ended').listen((event) {
      // **끝맺은 세션에 신호가 한 번 더 올 수 있습니다.** 중지한 뒤 '완전히
      // 끄기'를 누르면 그렇습니다. 두 번째 신호는 빈 값이라, 막지 않으면
      // 방금 받은 결과를 null로 덮고 이미 완료된 Completer에 complete을
      // 불러 StateError를 던집니다.
      final pending = _sessionEnded;
      if (pending == null || pending.isCompleted) return;

      _endedSaved = event?['saved'] == true;
      _endedStats = event != null && event['sampleCount'] != null
          ? SleepNoiseStats.fromPayload(event)
          : null;
      pending.complete();
    });
  }

  /// 방금 끝난 측정의 집계. 표본이 없으면 null입니다.
  SleepNoiseStats? _endedStats;

  /// 수면 기록을 제대로 닫았는지. 판정과는 별개입니다 — 집계는 메모리에서
  /// 나오므로 이 값이 false여도 결과는 보여줍니다. 다만 저장까지 됐다고
  /// 말하지는 않습니다.
  bool _endedSaved = false;

  /// 백그라운드가 끝났다고 알려 주기를 기다리는 자리.
  ///
  /// 중지 신호를 보낸 뒤 마지막 저장이 끝나기까지 잠깐 걸립니다. 고정 시간을
  /// 자는 대신 **실제 신호**를 기다립니다. 신호가 영영 안 오는 경우를 대비해
  /// 위쪽에서 시간 제한을 겁니다.
  Completer<void>? _sessionEnded;

  // 🚨 [위험 단계 판단 로직]
  Map<String, dynamic> _getDangerLevel(double db) {
    if (!_isNoiseMeasuring) {
      return {
        "color": Colors.blueGrey[50]!,
        "textColor": Colors.blueGrey[700]!,
        "text": "측정 대기 중",
        "icon": Icons.radar,
      };
    }

    // 구간은 NoiseRules와 같은 값을 씁니다. 여기서 따로 숫자를 적으면
    // 실시간 표시와 최종 판정이 어긋납니다.
    if (db < NoiseRules.normalLimit) {
      return {
        "color": Colors.green[50]!,
        "textColor": Colors.green[700]!,
        "text": "정상 (조용한 편이에요)",
        "icon": Icons.check_circle,
      };
    } else if (db <= NoiseRules.improveLimit) {
      return {
        "color": Colors.orange[50]!,
        "textColor": Colors.orange[800]!,
        "text": "주의 (수면 방해가 시작되는 구간)",
        "icon": Icons.warning_amber_rounded,
      };
    } else {
      return {
        "color": Colors.red[50]!,
        "textColor": Colors.red[800]!,
        // '위험' 대신 무엇을 하면 되는지를 씁니다(안전장치 1).
        "text": "개선 권장 (소음을 줄여 주세요)",
        "icon": Icons.volume_up,
      };
    }
  }

  /// 결과를 만들지 못한 이유를 알려줍니다.
  ///
  /// 예전에는 조용히 돌아가서, 중지 버튼이 2초 돌다 원래대로 오고 아무 일도
  /// 일어나지 않았습니다. 사용자는 무엇이 잘못됐는지 알 수 없었습니다.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 측정을 멈춘 뒤 판정 결과를 보여줍니다.
  ///
  /// 소음 로그는 **백그라운드 isolate**가 씁니다. 이 화면(UI isolate)은
  /// 그 인스턴스에 접근할 수 없어, 방금 끝난 수면 기록을 다시 조회해
  /// 통계를 계산합니다.
  Future<void> _showResult() async {
    setState(() => _loadingResult = true);
    try {
      // 백그라운드가 끝났다고 알려 줄 때까지 기다립니다. 고정 2초를 자던
      // 자리입니다 — 느린 망에서는 모자랐고, 빠를 때는 그냥 2초를 버렸습니다.
      await (_sessionEnded?.future ?? Future<void>.value())
          .timeout(const Duration(seconds: 15), onTimeout: () {});

      // 신호가 왔는지 먼저 봅니다. 안 왔으면 집계가 없는 것과 구별해야
      // 합니다 — 하나는 "못 받았다", 다른 하나는 "소리가 없었다"입니다.
      if (!(_sessionEnded?.isCompleted ?? false)) {
        _notify('측정을 끝맺지 못했습니다. 잠시 후 다시 시도해 주세요.');
        return;
      }

      // 집계는 백그라운드가 실어 보낸 값입니다. **DB를 보지 않습니다** —
      // 소음 수치는 어디에도 저장하지 않고, 남는 곳은 아래에서 만드는 판정
      // 한 행뿐입니다(assessments.inputs).
      final stats = _endedStats;
      final assessment = stats == null
          ? null
          : NoiseRules.assess(
              averageDb: stats.averageDb,
              maxDb: stats.maxDb,
              sampleCount: stats.sampleCount,
            );

      if (assessment == null) {
        // 집계가 메모리에서 나오므로 0건은 정말 소리를 못 받은 것입니다
        // (마이크 권한, 스트림이 죽음). 저장 실패와는 무관합니다.
        _notify(stats == null
            ? '소리를 하나도 받지 못했습니다. 마이크 권한을 확인하고 다시 측정해 주세요.'
            : '측정 시간이 짧아 판정하지 않았습니다. 조금 더 길게 측정해 주세요.');
        return;
      }

      // **판정을 만든 뒤에 아이를 찾습니다.** 예전에는 이 조회가 맨 앞에
      // 있어서, 망이 끊긴 밤이면 여기서 걸려 결과를 통째로 버렸습니다 —
      // 집계는 메모리에 멀쩡히 있는데 화면에는 '결과를 불러오지 못했습니다'만
      // 떴습니다. 아이를 못 찾는 것은 **저장을 못 하는 이유**이지 결과를
      // 못 보여줄 이유가 아닙니다.
      String? saveFailure;
      try {
        final baby = await BabyService.loadCurrent()
            .timeout(const Duration(seconds: 8));
        if (baby == null) {
          saveFailure = '아이 정보가 없어 판정을 저장하지 못했습니다.';
        } else {
          // 저장을 mounted 검사보다 먼저 합니다. 결과를 기다리는 사이에
          // 화면을 나가면 판정이 사라졌습니다. 한 시간을 잰 판정을 다시 만들
          // 길은 없습니다.
          await AssessmentService.save(babyId: baby.id, assessment: assessment);
        }
      } catch (e) {
        // **삼키지 않습니다.** 011 이후 이 숫자가 남는 곳은 판정 한 행뿐이고,
        // 백그라운드는 이미 메모리를 비웠습니다. 여기서 실패하면 그 밤의
        // 수치는 영영 사라지는데, 예전에는 debugPrint만 하고 결과 화면을
        // 정상적으로 띄워 저장된 줄 알게 했습니다.
        debugPrint('소음 판정 저장 실패: $e');
        saveFailure = '판정을 저장하지 못했습니다. 이 결과는 기록에 남지 않습니다.';
      }

      // 수면 기록을 못 닫은 것과 판정을 못 저장한 것은 다릅니다. 둘 다
      // 있으면 더 무거운 쪽(판정)을 말합니다 — 수면 기록은 다시 적을 수
      // 있지만 판정은 이 밤에만 만들 수 있습니다.
      if (saveFailure != null) {
        _notify('$saveFailure 결과는 아래에서 확인하실 수 있어요.');
      } else if (!_endedSaved) {
        _notify('판정은 저장했지만 수면 기록을 닫지 못했습니다. '
            '연결을 확인해 주세요.');
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoiseResultPage(
            assessment: assessment,
            saveFailure: saveFailure,
          ),
        ),
      );
    } catch (e) {
      debugPrint('소음 결과 조회 실패: $e');
      _notify('결과를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loadingResult = false);
    }
  }

  /// 측정 종료 후 결과를 불러오는 중인지.
  bool _loadingResult = false;

  void _toggleNoiseMeasurement() async {
    final service = FlutterBackgroundService();

    if (_isNoiseMeasuring) {
      // **버튼을 먼저 잠급니다.** 바로 아래 토큰 갱신이 망에 따라 몇 초
      // 걸리는데, 그동안 버튼 글씨가 그대로라 죽은 줄 알고 다시 누릅니다.
      // 그러면 이 갈래에 두 번 들어와 결과 화면도 판정도 두 번 생깁니다
      // (AssessmentService.save는 중복을 걸러 내지 않습니다).
      if (_loadingResult) return;
      setState(() {
        _loadingResult = true;
        _isNoiseMeasuring = false;
        _currentDecibel = 0.0;
      });

      _armSessionWait();
      // 멈추는 순간 백그라운드가 수면 기록을 닫습니다. 밤새 재고 아침에
      // 누르는 경우가 흔해, 시작할 때 넘긴 토큰은 이미 만료됐을 수 있습니다.
      await pushAuthToBackground();
      service.invoke('stopNoiseOnly');
      await _showResult();
      return;
    }

    _armSessionWait();

    setState(() => _starting = true);
    final started = await _startMeasuring();
    if (!mounted) return;

    setState(() {
      _starting = false;
      // 서비스가 실제로 시작했다고 답한 경우에만 '측정 중'으로 바꿉니다.
      _isNoiseMeasuring = started;
    });

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('측정을 시작하지 못했습니다. 마이크 권한을 확인한 뒤 다시 시도해 주세요.'),
        ),
      );
    }
  }

  /// 종료 신호를 받을 자리를 만듭니다.
  ///
  /// **측정을 시작할 때만 만들면 안 됩니다.** 밤잠의 표준 흐름이 그렇습니다 —
  /// 저녁에 시작하고, 화면을 나가거나 앱이 죽고, 아침에 다시 들어와 중지를
  /// 누릅니다. 그때 이 화면은 측정 시작을 본 적이 없어 기다릴 자리가 없고,
  /// 기다리지 않으면 8시간 잰 밤의 판정이 통째로 안 나옵니다.
  ///
  /// 지난 측정의 값도 함께 지웁니다. 남아 있으면 이번 결과가 그쪽을 봅니다.
  void _armSessionWait() {
    if (_sessionEnded != null && !_sessionEnded!.isCompleted) return;
    _endedStats = null;
    _endedSaved = false;
    _sessionEnded = Completer<void>();
  }

  /// 서비스를 켜고, 측정이 실제로 시작될 때까지 기다립니다.
  ///
  /// [FlutterBackgroundService.startService]는 서비스가 뜬 것까지만 기다리고,
  /// 그 안에서 신호를 받을 준비가 끝났는지는 알려주지 않습니다. 준비 전에 보낸
  /// 신호는 그냥 사라지므로, 시작했다는 답이 올 때까지 되풀이해 보냅니다.
  /// 서비스 쪽에서 중복 신호를 걸러 주므로 기록이 겹치지 않습니다.
  Future<bool> _startMeasuring() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }

    // 백그라운드는 스스로 로그인하지 않습니다. 수면 기록 행을 만들려면
    // 지금 토큰이 있어야 하므로 시작 신호보다 **먼저** 보냅니다.
    await pushAuthToBackground();

    final ack = _startAck = Completer<bool>();
    try {
      for (var i = 0; i < 12; i++) {
        service.invoke('startNoiseOnly', {'sleepType': _sleepType.name});

        final ok = await Future.any([
          ack.future,
          Future<bool>.delayed(const Duration(milliseconds: 500), () => false),
        ]);
        if (ok) return true;
      }
      return false;
    } finally {
      _startAck = null;
    }
  }

  /// 밤잠 / 낮잠 선택. 측정 중에는 잠깁니다.
  Widget _buildSleepTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNoiseMeasuring ? '${_sleepType.label} 기록 중' : '어떤 잠을 기록할까요?',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final type in SleepType.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: _isNoiseMeasuring
                      ? null
                      : () => setState(() => _sleepType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _sleepType == type
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sleepType == type
                            ? AppColors.primary
                            : context.colors.border,
                        width: _sleepType == type ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      type.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        // 측정 중에는 선택된 쪽만 또렷하게 보여줍니다.
                        color: _sleepType == type
                            ? AppColors.primary
                            : (_isNoiseMeasuring ? context.colors.border : context.colors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
              if (type != SleepType.values.last) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _getDangerLevel(_currentDecibel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('수면 소음 케어'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            _buildSleepTypeSelector(),
            const SizedBox(height: 20),

            // 🔊 [1] 실시간 데시벨 측정 + 위험도 표시 스크린 UI
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: currentStatus["color"] as Color,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (currentStatus["textColor"] as Color).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(currentStatus["icon"] as IconData, color: currentStatus["textColor"] as Color, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        currentStatus["text"] as String,
                        style: TextStyle(
                          fontSize: 16,
                          color: currentStatus["textColor"] as Color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _isNoiseMeasuring ? _currentDecibel.toStringAsFixed(1) : '0.0',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: _isNoiseMeasuring ? currentStatus["textColor"] as Color : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('dB',
                          style: TextStyle(
                            fontSize: 20,
                            // 카드 바탕이 상태에 따라 정해지므로 글씨도 같은
                            // 짝을 씁니다. 테마 색을 쓰면 어두운 테마에서
                            // 밝은 카드 위에 밝은 글씨가 됩니다.
                            color: currentStatus['textColor'] as Color,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    // 결과를 불러오거나 시작을 기다리는 동안 다시 누르면 꼬입니다.
                    onPressed: (_loadingResult || _starting)
                        ? null
                        : _toggleNoiseMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNoiseMeasuring ? Colors.grey[800] : AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: (_loadingResult || _starting)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(_isNoiseMeasuring ? Icons.mic_off : Icons.mic),
                    label: Text(
                      _loadingResult
                          ? '결과를 정리하는 중…'
                          : _starting
                              ? '측정을 준비하는 중…'
                              : _isNoiseMeasuring
                                  ? '소음 측정 중지하기'
                                  : '실시간 소음 측정 시작',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 🎵 [2] 백색소음 제어 및 이동 섹션 (★ 싱글톤 상태 연동)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _noiseService.isPlaying ? Icons.music_note : Icons.music_off,
                        color: _noiseService.isPlaying ? Colors.orange : context.colors.textSecondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _noiseService.isPlaying
                              ? '백색소음이 재생 중입니다 🎵'
                              : '백색소음이 꺼져 있습니다',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '원하는 백색소음을 틀어둔 상태로 실시간 데시벨을 측정해 보세요.',
                    style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // ★ 백색소음 선택 페이지로 갔다가 뒤로 돌아오면 UI 상태 즉시 업데이트
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WhiteNoisePage()),
                      );
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.graphic_eq_rounded),
                    label: Text(
                      _noiseService.isPlaying ? '백색소음 변경 / 관리하기' : '백색소음 선택하러 가기',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            TextButton.icon(
              onPressed: () async {
                // 재던 중에 이 버튼을 누르면 그 밤도 결과를 봐야 합니다.
                // 예전에는 그냥 껐고, 8시간을 재고도 판정이 만들어지지
                // 않았습니다. 백그라운드는 이제 끝맺음을 알려주지만
                // (main.dart의 stopService), 받아서 결과를 여는 것은
                // 이쪽 몫입니다.
                if (_loadingResult) return;
                final wasMeasuring = _isNoiseMeasuring;
                if (wasMeasuring) {
                  // 여기도 아래 토큰 갱신을 기다립니다. 잠그지 않으면
                  // 같은 이유로 결과가 두 번 열립니다.
                  setState(() => _loadingResult = true);
                  _armSessionWait();
                }

                // **재는 중이 아니어도 보냅니다.** 화면이 '측정 중이 아님'인
                // 것과 백그라운드에 쓸 것이 남아 있는 것은 다릅니다 —
                // 마이크 스트림이 죽으면 main.dart의 onError가 화면 상태만
                // 내리고 집계는 메모리에 그대로 남습니다. 그때 토큰을 안
                // 보내면 백그라운드의 마지막 쓰기가 401로 실패해
                // ended_at이 null로 남고, 기록 탭에 영영 '측정 중'입니다.
                await pushAuthToBackground();

                FlutterBackgroundService().invoke('stopService');
                _noiseService.stopAll(() {}); // 수면 시스템 꺼질 때 백색소음도 같이 정지
                setState(() {
                  _isNoiseMeasuring = false;
                  _currentDecibel = 0.0;
                });

                if (wasMeasuring) await _showResult();
              },
              icon: const Icon(Icons.power_settings_new, color: Colors.red),
              label: const Text('수면 케어 전체 시스템 완전히 끄기', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}