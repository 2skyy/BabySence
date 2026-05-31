import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NoiseTracker {
  final List<Map<String, dynamic>> _noiseBuffer = [];

  // 서버 URL 및 recordId를 설정하기 위한 변수
  // 안드로이드 에뮬레이터에서 로컬 PC의 Spring Boot에 접근하려면 10.0.2.2를 사용합니다.
  // 실기기로 테스트 중이라면 PC의 와이파이 IPv4 주소(예: 192.168.0.x)를 입력해야 합니다.
  final String _serverBaseUrl = 'http://127.0.0.1:8080'; // <-- ★ 본인 환경에 맞게 수정 필수!
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