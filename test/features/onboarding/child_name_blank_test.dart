import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/onboarding/child_info_page.dart';

/// 공백만 적은 이름을 아이 이름으로 받지 않습니다.
///
/// 검사는 `isEmpty`로 하고 저장은 `trim()`한 값으로 했습니다. 그래서 스페이스
/// 하나만 적으면 검사를 지나고 **이름이 빈 아이**가 만들어집니다. 이름은
/// 나중에 고칠 수단이 있지만, 그 전까지 접종 알림이 "  예방접종 예정일이
/// 다가와요"로 뜨고 홈 인사말도 빈칸으로 나옵니다.
void main() {
  Future<void> fillForm(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ChildInfoPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, name);

    // 생년월일 — 달력을 열고 오늘로 정합니다.
    await tester.tap(find.text('생년월일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('남아'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '3.2');
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장하고 시작하기'));
    await tester.pump();
  }

  testWidgets('공백만 적은 이름은 되돌려 보낸다', (tester) async {
    await fillForm(tester, '   ');
    expect(find.text('모든 정보를 입력해주세요.'), findsOneWidget,
        reason: '공백 이름이 검사를 지나 빈 이름으로 저장됩니다');
  });
}
