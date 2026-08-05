import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/shell/more_page.dart';

void main() {
  Future<void> pump(WidgetTester tester, {double textScale = 1.0}) async {
    // 기본 테스트 화면(800x600)은 실제 폰보다 짧아 아래 항목이 그려지지 않습니다.
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const MaterialApp(home: MorePage()),
      ),
    );
  }

  testWidgets('메뉴 항목을 모두 보여준다', (tester) async {
    await pump(tester);

    expect(find.text('전체'), findsOneWidget);
    for (final label in [
      '마이페이지',
      '설정',
      '육아 가이드',
      '진료용 리포트',
      '공지사항',
      '1:1 문의하기',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('버전을 보여준다', (tester) async {
    await pump(tester);
    expect(find.text('버전 ${MorePage.appVersion}'), findsOneWidget);
  });

  testWidgets('아직 없는 기능은 준비 중 화면으로 보낸다', (tester) async {
    // 눌러도 아무 반응이 없으면 고장으로 보입니다.
    await pump(tester);

    await tester.tap(find.text('육아 가이드'));
    await tester.pumpAndSettle();

    expect(find.text('준비 중입니다'), findsOneWidget);
  });

  testWidgets('로그아웃은 여기 두지 않는다', (tester) async {
    // 설정의 '계정' 한 곳에만 둡니다. 두 곳에 있으면 어느 쪽이 진짜인지
    // 헷갈리고, 한쪽만 고치는 실수가 생깁니다.
    await pump(tester);
    expect(find.text('로그아웃'), findsNothing);
  });

  testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
    await pump(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
