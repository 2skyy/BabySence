import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/diaper_record_page.dart';

/// 소변에는 대변 상태가 없습니다.
///
/// `diaper_records`의 CHECK 제약이 소변일 때 `stool_state`를 NULL로 두게
/// 하므로, 서비스도 그렇게 저장합니다. 그런데 화면에서는 고를 수 있게
/// 두어서, 고른 값이 저장된다고 오해하기 쉬웠습니다.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Supabase 없이 띄웁니다. 이력 조회는 실패하지만 입력 부분은 그려집니다.
    await tester.pumpWidget(const MaterialApp(home: DiaperRecordPage()));
    await tester.pump();
  }

  testWidgets('처음 열면 소변이라 대변 상태가 없다', (tester) async {
    await pump(tester);

    expect(find.text('대변 상태'), findsNothing);
    expect(find.text('황금변'), findsNothing);
  });

  testWidgets('대변을 고르면 상태가 나온다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('대변'));
    await tester.pump();

    expect(find.text('대변 상태'), findsOneWidget);
    expect(find.text('황금변'), findsOneWidget);
  });

  testWidgets('혼합에도 대변이 섞여 있으므로 나온다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('혼합'));
    await tester.pump();

    expect(find.text('대변 상태'), findsOneWidget);
  });

  testWidgets('대변에서 소변으로 되돌리면 다시 사라진다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('대변'));
    await tester.pump();
    await tester.tap(find.text('소변'));
    await tester.pump();

    expect(find.text('대변 상태'), findsNothing);
  });
}
