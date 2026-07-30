import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// ★ 백색소음 선택 페이지 및 싱글톤 서비스 import
import './white_noise_page.dart';
import './white_noise_service.dart';
import '../../core/services/noise_tracker.dart' show SleepType;

class NoiseTestPage extends StatefulWidget {
  const NoiseTestPage({super.key});

  @override
  State<NoiseTestPage> createState() => _NoiseTestPageState();
}

class _NoiseTestPageState extends State<NoiseTestPage> {
  double _currentDecibel = 0.0; // 실시간 데시벨 수치 저장
  bool _isNoiseMeasuring = false;
  StreamSubscription? _serviceSubscription;

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
    super.dispose();
  }

  void _checkInitialStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _isNoiseMeasuring = isRunning;
    });
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

    if (db < 50.0) {
      return {
        "color": Colors.green[50]!,
        "textColor": Colors.green[700]!,
        "text": "안전 (쾌적한 수면 환경)",
        "icon": Icons.check_circle,
      };
    } else if (db >= 50.0 && db < 70.0) {
      return {
        "color": Colors.orange[50]!,
        "textColor": Colors.orange[800]!,
        "text": "주의 (아기가 깰 수 있어요)",
        "icon": Icons.warning_amber_rounded,
      };
    } else {
      return {
        "color": Colors.red[50]!,
        "textColor": Colors.red[800]!,
        "text": "위험 (소음 차단 필요!!)",
        "icon": Icons.gpp_bad_rounded,
      };
    }
  }

  void _toggleNoiseMeasurement() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (_isNoiseMeasuring) {
      service.invoke('stopNoiseOnly');
      setState(() {
        _isNoiseMeasuring = false;
        _currentDecibel = 0.0;
      });
    } else {
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('startNoiseOnly', {'sleepType': _sleepType.name});
      setState(() {
        _isNoiseMeasuring = true;
      });
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
                          ? const Color(0xFF0059B9).withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sleepType == type
                            ? const Color(0xFF0059B9)
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
                            ? const Color(0xFF0059B9)
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
        backgroundColor: const Color(0xFF0059B9),
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
                          color: _isNoiseMeasuring ? currentStatus["textColor"] as Color : const Color(0xFF0059B9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('dB', style: TextStyle(fontSize: 20, color: Colors.black45, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    onPressed: _toggleNoiseMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNoiseMeasuring ? Colors.grey[800] : const Color(0xFF0059B9),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_isNoiseMeasuring ? Icons.mic_off : Icons.mic),
                    label: Text(_isNoiseMeasuring ? '소음 측정 중지하기' : '실시간 소음 측정 시작'),
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