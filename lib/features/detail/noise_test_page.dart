import 'dart:async';
import 'dart:io' show Platform; // ★ 플랫폼 확인용 추가
import 'package:flutter/foundation.dart' show kIsWeb; // ★ 웹 환경 확인용 추가
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
// 기존에 만든 NoiseTracker import (경로는 프로젝트에 맞게 수정)
import '../../core/services/noise_tracker.dart';
// ★ 결과 화면 import 추가 (경로가 같은 detail 폴더 안이라고 가정)
import 'noise_result_page.dart';

class NoiseTestPage extends StatefulWidget {
  const NoiseTestPage({super.key});

  @override
  State<NoiseTestPage> createState() => _NoiseTestPageState();
}

class _NoiseTestPageState extends State<NoiseTestPage> {
  bool _isRecording = false;
  double _currentDecibel = 0.0;
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

  // 마이크 권한 확인 및 측정 시작
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

    // ★ 방어 코드 추가: 안드로이드/iOS일 때만 백그라운드 서비스 켜기 ★
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        service.startService();
      }
    }

    setState(() {
      _isRecording = true;
    });

    try {
      _noiseSubscription = _noiseMeter.noise.listen(
            (NoiseReading noiseReading) {
          setState(() {
            _currentDecibel = noiseReading.meanDecibel; // 평균 데시벨
          });
          // 측정한 데시벨을 서버 전송용 트래커에 전달!
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
    setState(() {
      _isRecording = false;
      _currentDecibel = 0.0;
    });
    _noiseSubscription?.cancel();

    // ★ 방어 코드 추가: 안드로이드/iOS일 때만 백그라운드 서비스 끄기 ★
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
    }

    // ★ 측정 중지 후 결과 화면으로 이동! (테스트를 위해 recordId는 1로 하드코딩)
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NoiseResultPage(recordId: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('수면 소음 측정 테스트')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '현재 소음',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              '${_currentDecibel.toStringAsFixed(1)} dB',
              style: TextStyle(
                fontSize: 60,
                color: _currentDecibel > 55 ? Colors.red : Colors.green, // 55dB 넘으면 빨간색
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