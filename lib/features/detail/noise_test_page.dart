import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// ★ 백색소음 선택 페이지 및 싱글톤 서비스 import
import './white_noise_page.dart';
import './white_noise_service.dart';
import '../../core/services/baby_service.dart';
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
  }

  // 🚨 [위험 단계 판단 로직]
  Map<String, dynamic> _getDangerLevel(double db) {
    if (!_isNoiseMeasuring) {
      return {
        "color": Colors.blueGrey[50]!,
        "textColor": Colors.grey[700]!,
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

  /// 측정을 멈춘 뒤 판정 결과를 보여줍니다.
  ///
  /// 소음 로그는 **백그라운드 isolate**가 씁니다. 이 화면(UI isolate)은
  /// 그 인스턴스에 접근할 수 없어, 방금 끝난 수면 기록을 다시 조회해
  /// 통계를 계산합니다.
  Future<void> _showResult() async {
    setState(() => _loadingResult = true);
    try {
      // 중지 직후에는 남은 로그를 저장하는 중일 수 있습니다. 잠시 기다린 뒤
      // 조회합니다. 그래도 부족하면 아래에서 표본 부족으로 안내합니다.
      await Future.delayed(const Duration(seconds: 2));

      final baby = await BabyService.loadCurrent();
      if (baby == null) return;

      final recent = await SleepRecordService.loadRecent(baby.id, limit: 1);
      if (recent.isEmpty) return;

      final stats = await SleepRecordService.loadNoiseStats(recent.first.id);
      final assessment = NoiseRules.assess(
        averageDb: stats.averageDb,
        maxDb: stats.maxDb,
        sampleCount: stats.sampleCount,
      );

      if (!mounted) return;

      if (assessment == null) {
        // 표본이 적으면 판정하지 않습니다. 근거 없는 안내보다 낫습니다.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('측정 시간이 짧아 판정하지 않았습니다. 조금 더 길게 측정해 주세요.'),
          ),
        );
        return;
      }

      // 판정은 앱에서 계산하므로 저장이 실패해도 결과는 보여줄 수 있습니다.
      try {
        await AssessmentService.save(babyId: baby.id, assessment: assessment);
      } catch (e) {
        debugPrint('소음 판정 저장 실패: $e');
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoiseResultPage(assessment: assessment),
        ),
      );
    } catch (e) {
      debugPrint('소음 결과 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingResult = false);
    }
  }

  /// 측정 종료 후 결과를 불러오는 중인지.
  bool _loadingResult = false;

  void _toggleNoiseMeasurement() async {
    final service = FlutterBackgroundService();

    if (_isNoiseMeasuring) {
      service.invoke('stopNoiseOnly');
      setState(() {
        _isNoiseMeasuring = false;
        _currentDecibel = 0.0;
      });
      await _showResult();
      return;
    }

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
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sleepType == type
                            ? AppColors.primary
                            : Colors.grey[300]!,
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
                            : (_isNoiseMeasuring ? Colors.grey[350] : Colors.grey[600]),
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
                      const Text('dB', style: TextStyle(fontSize: 20, color: Colors.black45, fontWeight: FontWeight.bold)),
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _noiseService.isPlaying ? Icons.music_note : Icons.music_off,
                        color: _noiseService.isPlaying ? Colors.orange : Colors.grey,
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
                  const Text(
                    '원하는 백색소음을 틀어둔 상태로 실시간 데시벨을 측정해 보세요.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
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
              onPressed: () {
                FlutterBackgroundService().invoke('stopService');
                _noiseService.stopAll(() {}); // 수면 시스템 꺼질 때 백색소음도 같이 정지
                setState(() {
                  _isNoiseMeasuring = false;
                  _currentDecibel = 0.0;
                });
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