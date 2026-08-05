import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/sleep_record_page.dart';

/// 수면 기록 화면의 시간 입력 칸이 좁은 기기에서 넘치지 않는지 봅니다.
///
/// 오전/오후 드롭다운과 시:분 입력이 한 줄에 들어가는데, 폭이 고정이라
/// 글자 크기 설정이 크거나 화면이 좁으면 overflow가 납니다.
void main() {
  /// 지정한 논리 해상도와 글자 배율로 화면을 그립니다.
  Future<void> pumpAt(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const MaterialApp(home: SleepRecordPage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('iPhone SE 폭(375)에서 시간 칸이 넘치지 않는다', (tester) async {
    await pumpAt(tester, size: const Size(375, 812));
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 기기 폭(320)에서도 넘치지 않는다', (tester) async {
    await pumpAt(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('글자 크기를 키워도(1.3배) 넘치지 않는다', (tester) async {
    // 시스템 글자 크기를 키운 사용자가 적지 않습니다.
    await pumpAt(tester, size: const Size(375, 812), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
