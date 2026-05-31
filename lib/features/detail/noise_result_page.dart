import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NoiseResultPage extends StatefulWidget {
  final int recordId; // 어떤 수면 기록의 결과를 볼 것인지 전달받음

  const NoiseResultPage({super.key, required this.recordId});

  @override
  State<NoiseResultPage> createState() => _NoiseResultPageState();
}

class _NoiseResultPageState extends State<NoiseResultPage> {
  bool _isLoading = true;
  String _analysisReport = "";
  bool _isError = false;

  // 본인의 환경(실기기/에뮬레이터)에 맞게 IP를 수정하세요 (테스트 때 맞춘 주소와 동일하게)
  final String _serverBaseUrl = 'http://127.0.0.1:8080';

  @override
  void initState() {
    super.initState();
    _fetchAnalysisResult();
  }

  // 백엔드(Spring Boot)에 분석 결과(가이드 문구)를 요청하는 함수
  Future<void> _fetchAnalysisResult() async {
    try {
      final url = Uri.parse('$_serverBaseUrl/api/sleep-records/${widget.recordId}/analysis');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // 서버가 반환한 텍스트 그대로 사용 (한글 깨짐 방지를 위해 utf8 디코딩)
        final decodedResponse = utf8.decode(response.bodyBytes);
        setState(() {
          _analysisReport = decodedResponse;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isError = true;
          _isLoading = false;
          _analysisReport = "결과를 불러오는 데 실패했습니다. (상태 코드: ${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _isLoading = false;
        _analysisReport = "네트워크 에러가 발생했습니다. 서버가 켜져 있는지 확인해 주세요.\n$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 분석 내용에 따라 상태 아이콘과 색상 결정 (간단한 키워드 매칭)
    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.green;
    String statusTitle = "정상";

    if (_analysisReport.contains("확률이 70%로 매우 높습니다") || _analysisReport.contains("상담 권장")) {
      statusIcon = Icons.warning_rounded;
      statusColor = Colors.redAccent;
      statusTitle = "주의 / 상담 권장";
    } else if (_analysisReport.contains("확률이 40%")) {
      statusIcon = Icons.info_outline;
      statusColor = Colors.orangeAccent;
      statusTitle = "주의";
    }

    return Scaffold(
      appBar: AppBar(title: const Text('수면 소음 분석 결과')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AI INSIGHT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          '현재 상태: $statusTitle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, thickness: 1),
                    const Text(
                      '맞춤 행동 가이드',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isError ? _analysisReport : _analysisReport,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }
}