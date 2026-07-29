import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NoiseTracker {
  final List<Map<String, dynamic>> _noiseBuffer = [];
  final String _serverBaseUrl = "http://127.0.0.1:8080";
  final int _currentRecordId = 1;

  // ★ 추가: 수치 널뛰기를 잡아줄 이동 평균 저장 변수
  double _smoothedDb = 0.0;

  void onNoiseLevelChanged(double currentDb) {
    if (currentDb.isInfinite || currentDb.isNaN) {
      return;
    }

    // ★ 1단계 [감도 낮추기]: 스마트폰 마이크 기본 화이트노이즈를 고려해 8dB 차감 (필요에 따라 5~10 사이로 조절)
    double adjustedDb = currentDb - 8.0;
    if (adjustedDb < 0) adjustedDb = 0.0; // 음수 방지

    // ★ 2단계 [널뛰기 방지]: 이전 수치와 새 수치를 7:3 비율로 섞어 갑자기 숫자가 치솟는 현상 방지
    _smoothedDb = (_smoothedDb == 0.0)
        ? adjustedDb
        : (_smoothedDb * 0.7) + (adjustedDb * 0.3);

    // ★ 보정되고 부드러워진 최종 데시벨(_smoothedDb)을 버퍼에 저장
    _noiseBuffer.add({
      "measured_at": DateTime.now().toIso8601String(),
      "decibel": double.parse(_smoothedDb.toStringAsFixed(1)),
    });

    if (_noiseBuffer.length >= 30) {
      _sendBatchToServer();
    }
  }

  Future<void> _sendBatchToServer() async {
    if (_noiseBuffer.isEmpty) return;

    List<Map<String, dynamic>> dataToSend = List.from(_noiseBuffer);
    _noiseBuffer.clear();

    try {
      final url = Uri.parse('$_serverBaseUrl/api/sleep-records/$_currentRecordId/noise');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"noise_logs": dataToSend}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('소음 데이터 배치 전송 성공 (데이터 수: ${dataToSend.length})');
      } else {
        debugPrint('전송 실패: 서버 에러 (상태 코드: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('백그라운드 네트워크 전송 에러: $e');
    }
  }
}