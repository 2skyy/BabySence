import 'package:flutter/material.dart';

class SkinAnalysisPage extends StatelessWidget {
  const SkinAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('피부 분석'),
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '피부 사진을 업로드하면\nAI가 피부 상태를 알려드립니다.',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '발진, 습진, 건조함 같은 상태를 확인하는 기능으로 준비하면 됩니다.',
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
                    '사진 업로드 UI 예정',
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
