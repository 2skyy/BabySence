import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project/features/detail/growth/growth_record_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows profile setup when no profile exists, then the record form after setup', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GrowthRecordPage()));
    await tester.pumpAndSettle();

    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('남아'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('기록 추가'), findsOneWidget);
    expect(find.text('몸무게 (kg)'), findsWidgets);
  });

  testWidgets('adding a record shows it in the history list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GrowthRecordPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '키 (cm)'), '60');
    await tester.enterText(find.widgetWithText(TextField, '몸무게 (kg)'), '5.5');
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();

    expect(find.text('기록 이력'), findsOneWidget);
    expect(find.textContaining('키 60.0cm'), findsOneWidget);
    expect(find.textContaining('몸무게 5.5kg'), findsOneWidget);
  });
}
