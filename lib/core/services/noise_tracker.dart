import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';

class NoiseTracker {
  final List<Map<String, dynamic>> _noiseBuffer = [];

  final String _serverBaseUrl = ApiConfig.baseUrl;
  final int _currentRecordId = 1; // 테스트용 임시 Record ID (추후 실제 ID로 대체)

  void onNoiseLevelChanged(double currentDb) {
    _noiseBuffer.add({
      "measured_at": DateTime.now().toIso8601String(),
      "decibel": currentDb,
    });

    if (_noiseBuffer.length >= 30) {
      _sendBatchToServer();
    }
  }

  Future<void> _sendBatchToServer() async {
    List<Map<String, dynamic>> dataToSend = List.from(_noiseBuffer);
    _noiseBuffer.clear();

    try {
      // URL을 동적으로 생성
      final url = Uri.parse('$_serverBaseUrl/api/sleep-records/$_currentRecordId/noise');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"noise_logs": dataToSend}),
      );

      if (response.statusCode == 200) {
        debugPrint('소음 데이터 배치 전송 성공 (데이터 수: ${dataToSend.length})');
      } else {
        debugPrint('전송 실패: 서버 에러 (상태 코드: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('네트워크 에러: $e');
    }
  }
}