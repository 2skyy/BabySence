import 'package:flutter/material.dart';

/// 소음 측정 결과를 최대 데시벨 기준으로 안내하는 화면.
///
/// 예전에는 Spring 서버의 /api/sleep-records/{id}/analysis를 불러왔지만,
/// 그 응답이 고정 문구였던 탓에 아래 규칙 기반 문구로 대체된 상태였습니다.
/// 서버 호출은 실제로 쓰이지 않아 제거했습니다.
class NoiseResultPage extends StatelessWidget {
  final double maxDb;

  const NoiseResultPage({super.key, required this.maxDb});

  @override
  Widget build(BuildContext context) {
    // 1. 실제 측정한 데시벨(maxDb) 기준으로 상단 타이틀과 색상 결정
    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.green;
    String statusTitle = "정상";

    // 2. 측정값에 맞춘 가이드 문구 생성
    String dynamicGuide = "";

    if (maxDb >= 70.0) {
      statusIcon = Icons.warning_rounded;
      statusColor = Colors.redAccent;
      statusTitle = "경고 / 환경 개선 필요";
      dynamicGuide = "분석 결과입니다.\n"
          "방금 측정된 최대 소음이 ${maxDb.toStringAsFixed(1)} dB까지 치솟아 매우 시끄러운 상태였습니다.\n"
          "이 정도 소음은 아기가 깜짝 놀라 잠에서 깰 수 있으므로, 주변 소음원을 차단하거나 기기 위치를 조정해 주세요!";
    } else if (maxDb >= 50.0) {
      statusIcon = Icons.info_outline;
      statusColor = Colors.orangeAccent;
      statusTitle = "주의 / 약간 시끄러움";
      dynamicGuide = "분석 결과입니다.\n"
          "측정 중 최대 소음이 ${maxDb.toStringAsFixed(1)} dB로 약간의 생활 소음이 감지되었습니다.\n"
          "아기가 중간에 깨지 않고 깊은 잠을 잘 수 있도록 조금 더 조용한 환경을 유지해 주는 것이 좋습니다.";
    } else {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
      statusTitle = "정상";
      dynamicGuide = "분석 결과입니다.\n"
          "최대 소음이 ${maxDb.toStringAsFixed(1)} dB 주변으로 매우 조용하고 쾌적하게 유지되었습니다.\n"
          "아기가 숙면을 취하기에 최적의 환경입니다. 현재 상태를 이대로 잘 유지해 주세요!";
    }

    final String finalReportToShow = dynamicGuide;

    return Scaffold(
      appBar: AppBar(title: const Text('수면 소음 분석 결과')),
      body: Padding(
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