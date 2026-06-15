import 'package:flutter/material.dart';

class CryAnalysisPage extends StatelessWidget {
  const CryAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('울음소리 분석'),
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '아이의 울음소리를 분석해\n어떤 의미인지 알려드립니다.',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '배고픔, 졸림, 불편함 같은 신호를 추정하는 기능으로 준비하면 됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(
                  child: Text(
                    '음성 업로드 UI 예정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('분석하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
