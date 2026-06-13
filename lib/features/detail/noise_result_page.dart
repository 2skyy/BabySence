import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NoiseResultPage extends StatefulWidget {
  final int recordId;
  final double maxDb; // ★ 추가: 측정 페이지에서 넘어온 실제 최대 데시벨 값

  const NoiseResultPage({super.key, required this.recordId, required this.maxDb});

  @override
  State<NoiseResultPage> createState() => _NoiseResultPageState();
}

class _NoiseResultPageState extends State<NoiseResultPage> {
  bool _isLoading = true;
  String _analysisReport = "";
  bool _isError = false;

  final String _serverBaseUrl = 'http://127.0.0.1:8080';

  @override
  void initState() {
    super.initState();
    _fetchAnalysisResult();
  }

  Future<void> _fetchAnalysisResult() async {
    try {
      final url = Uri.parse('$_serverBaseUrl/api/sleep-records/${widget.recordId}/analysis');
      final response = await http.get(url);

      if (response.statusCode == 200) {
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
    // ★ 수정: 서버의 텍스트가 아니라 '실제 측정한 데시벨(maxDb)' 기준으로 상태 결정
    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.green;
    String statusTitle = "정상";

    if (widget.maxDb >= 70.0) { // 70dB 이상이면 시끄러움 (경고)
      statusIcon = Icons.warning_rounded;
      statusColor = Colors.redAccent;
      statusTitle = "경고 / 환경 개선 필요";
    } else if (widget.maxDb >= 50.0) { // 50~70dB 사이면 주의
      statusIcon = Icons.info_outline;
      statusColor = Colors.orangeAccent;
      statusTitle = "주의 / 약간 시끄러움";
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
                    // ★ 수정: 내가 방금 낸 시끄러운 소리가 몇 dB였는지 화면에 명확하게 표시
                    Text(
                      '🔊 측정된 최대 소음: ${widget.maxDb.toStringAsFixed(1)} dB\n\n${_isError ? _analysisReport : _analysisReport}',
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