import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NoiseResultPage extends StatefulWidget {
  final int recordId;
  final double maxDb;

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
      final response = await http.get(url).timeout(const Duration(seconds: 10));

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
    } on TimeoutException {
      setState(() {
        _isError = true;
        _isLoading = false;
        _analysisReport = "서버 응답 시간이 초과되었습니다. adb reverse 연결을 확인해 주세요.";
      });
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
    // 1. 실제 측정한 데시벨(maxDb) 기준으로 상단 타이틀과 색상 결정
    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.green;
    String statusTitle = "정상";

    // 2. ★ 핵심: 서버의 45dB 고정 문구를 대체할 '실시간 맞춤형 가이드 텍스트' 생성
    String dynamicGuide = "";

    if (widget.maxDb >= 70.0) {
      statusIcon = Icons.warning_rounded;
      statusColor = Colors.redAccent;
      statusTitle = "경고 / 환경 개선 필요";
      dynamicGuide = "분석 결과입니다.\n"
          "방금 측정된 최대 소음이 ${widget.maxDb.toStringAsFixed(1)} dB까지 치솟아 매우 시끄러운 상태였습니다.\n"
          "이 정도 소음은 아기가 깜짝 놀라 잠에서 깰 수 있으므로, 주변 소음원을 차단하거나 기기 위치를 조정해 주세요!";
    } else if (widget.maxDb >= 50.0) {
      statusIcon = Icons.info_outline;
      statusColor = Colors.orangeAccent;
      statusTitle = "주의 / 약간 시끄러움";
      dynamicGuide = "분석 결과입니다.\n"
          "측정 중 최대 소음이 ${widget.maxDb.toStringAsFixed(1)} dB로 약간의 생활 소음이 감지되었습니다.\n"
          "아기가 중간에 깨지 않고 깊은 잠을 잘 수 있도록 조금 더 조용한 환경을 유지해 주는 것이 좋습니다.";
    } else {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
      statusTitle = "정상";
      dynamicGuide = "분석 결과입니다.\n"
          "최대 소음이 ${widget.maxDb.toStringAsFixed(1)} dB 주변으로 매우 조용하고 쾌적하게 유지되었습니다.\n"
          "아기가 숙면을 취하기에 최적의 환경입니다. 현재 상태를 이대로 잘 유지해 주세요!";
    }

    // 3. 만약 서버에서 에러가 났거나 45dB 고정 더미 데이터가 아니라 '진짜 새로운 분석 문구'를 보냈다면 서버 문구를 보여줌
    String finalReportToShow = dynamicGuide;
    if (_isError) {
      finalReportToShow = _analysisReport;
    } else if (!_analysisReport.contains("45dB") && _analysisReport.isNotEmpty) {
      // 서버가 발전해서 45dB 고정 텍스트가 아닌 진짜 분석 결과를 주기 시작했다면 그 결과를 반영
      finalReportToShow = _analysisReport;
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
                    // ★ 가공된 최종 동적 리포트를 화면에 출력합니다.
                    Text(
                      finalReportToShow,
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