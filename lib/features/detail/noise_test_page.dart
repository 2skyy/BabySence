import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../core/services/noise_tracker.dart';
import 'noise_result_page.dart';

class NoiseTestPage extends StatefulWidget {
  const NoiseTestPage({super.key});

  @override
  State<NoiseTestPage> createState() => _NoiseTestPageState();
}

class _NoiseTestPageState extends State<NoiseTestPage> {
  bool _isRecording = false;
  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;

  // ★ 스무딩을 위한 변수들
  final int _bufferSize = 7; // 숫자가 클수록 더 부드러워짐 (7~10 권장)
  final List<double> _dbBuffer = [];
  final double _calibrationOffset = -15.0; // 너무 높게 나오면 -20.0 등으로 줄이세요.

  StreamSubscription<NoiseReading>? _noiseSubscription;
  late NoiseMeter _noiseMeter;
  final NoiseTracker _noiseTracker = NoiseTracker();

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한을 허용해야 소음을 측정할 수 있습니다.')),
        );
      }
      return;
    }

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        service.startService();
      }
    }

    setState(() {
      _isRecording = true;
      _maxDecibel = 0.0;
      _dbBuffer.clear(); // 버퍼 초기화
    });

    try {
      _noiseSubscription = _noiseMeter.noise.listen(
            (NoiseReading noiseReading) {

          // ★ [스무딩 로직]
          double rawDb = noiseReading.meanDecibel + _calibrationOffset;
          if (rawDb < 0) rawDb = 0.0;

          _dbBuffer.add(rawDb);
          if (_dbBuffer.length > _bufferSize) _dbBuffer.removeAt(0);

          double smoothedDb = _dbBuffer.reduce((a, b) => a + b) / _dbBuffer.length;

          setState(() {
            _currentDecibel = smoothedDb;
            if (_currentDecibel > _maxDecibel) {
              _maxDecibel = _currentDecibel;
            }
          });

          _noiseTracker.onNoiseLevelChanged(_currentDecibel);
        },
        onError: (Object error) {
          debugPrint(error.toString());
          _stopRecording();
        },
      );
    } catch (err) {
      debugPrint(err.toString());
    }
  }

  void _stopRecording() async {
    double finalMaxDb = _maxDecibel;

    setState(() {
      _isRecording = false;
      _currentDecibel = 0.0;
    });
    _noiseSubscription?.cancel();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoiseResultPage(recordId: 1, maxDb: finalMaxDb),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 소음 데이터가 어떻게 처리되는지 한눈에 보는 로직 흐름도
    //
    return Scaffold(
      appBar: AppBar(title: const Text('수면 소음 측정 테스트')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '현재 소음 (스무딩 적용)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              '${_currentDecibel.toStringAsFixed(1)} dB',
              style: TextStyle(
                fontSize: 60,
                color: _currentDecibel > 55 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.redAccent : Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                _isRecording ? '측정 중지' : '측정 시작',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          ],
        ),
      ),
    );
  }
}