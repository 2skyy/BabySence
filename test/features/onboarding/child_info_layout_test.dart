import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/theme/app_theme.dart';
import 'package:flutter_project/features/onboarding/child_info_page.dart';

/// 아이 정보를 처음 적는 화면이 **어느 기기에서도 넘치지 않는지**.
///
/// 본문이 Column + Spacer뿐이라 스크롤이 없었습니다. 키 큰 화면에서는
/// Spacer가 단추를 아래로 밀어 보기 좋았지만, 작은 기기나 글씨를 키운
/// 경우에는 그대로 넘쳐 아래가 잘렸습니다. 여기서 막히면 앱을 시작조차
/// 할 수 없습니다.
void main() {
  Future<int> overflows(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());

    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: const MaterialApp(home: ChildInfoPage()),
    ));
    await tester.pumpAndSettle();

    FlutterError.onError = previous;
    tester.takeException();
    return errors.where((e) => e.contains('overflow')).length;
  }

  testWidgets('작은 기기에서 넘치지 않는다', (tester) async {
    // 320x640은 아직 쓰이는 가장 작은 축에 듭니다.
    expect(await overflows(tester, const Size(320, 640), 1.0), 0);
  });

  testWidgets('글씨를 키워도 넘치지 않는다', (tester) async {
    for (final scale in [1.3, 1.6]) {
      expect(await overflows(tester, const Size(320, 640), scale), 0,
          reason: '배율 $scale 에서 넘칩니다');
    }
  });

  testWidgets('큰 화면에서도 넘치지 않는다', (tester) async {
    expect(await overflows(tester, const Size(800, 632), 1.0), 0);
    expect(await overflows(tester, const Size(414, 896), 1.3), 0);
  });

  testWidgets('자리가 모자라면 스크롤된다', (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: MaterialApp(theme: AppTheme.lightTheme, home: const ChildInfoPage()),
    ));
    await tester.pumpAndSettle();

    // 저장 단추가 화면 밖에 있어도 끌어내려 닿을 수 있어야 합니다.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('저장하고 시작하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
