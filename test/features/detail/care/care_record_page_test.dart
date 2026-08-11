import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/care/care_record_page.dart';
import 'package:flutter_project/features/detail/widgets/record_time_field.dart';

/// Supabase 없이 띄웁니다. 이력 조회는 실패하지만 입력 부분은 그려집니다.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CareRecordPage()));
    await tester.pump();
  }

  testWidgets('약 복용으로 열린다', (tester) async {
    await pump(tester);

    expect(find.text('약 이름'), findsOneWidget);
    expect(find.text('먹인 이유'), findsOneWidget);
    // 병원 쪽 칸은 아직 없습니다.
    expect(find.text('진료 메모'), findsNothing);
  });

  testWidgets('병원 방문으로 바꾸면 칸이 바뀐다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('병원 방문'));
    await tester.pump();

    expect(find.text('진료 메모'), findsOneWidget);
    expect(find.text('방문 이유'), findsOneWidget);
    expect(find.text('약 이름'), findsNothing);
  });

  testWidgets('시간 라벨이 무엇을 적는지에 따라 달라진다', (tester) async {
    await pump(tester);
    expect(find.text('먹인 시간'), findsOneWidget);

    await tester.tap(find.text('병원 방문'));
    await tester.pump();
    expect(find.text('방문 시간'), findsOneWidget);
  });

  testWidgets('시간 입력은 다른 기록 화면과 같은 것을 쓴다', (tester) async {
    await pump(tester);
    expect(find.byType(RecordTimeField), findsOneWidget);
  });

  testWidgets('정기검진·예방접종은 병원 쪽에만 있다', (tester) async {
    // 약을 먹인 이유로는 성립하지 않습니다.
    await pump(tester);
    expect(find.text('정기검진'), findsNothing);

    await tester.tap(find.text('병원 방문'));
    await tester.pump();
    expect(find.text('정기검진'), findsOneWidget);
    expect(find.text('예방접종'), findsOneWidget);
  });

  testWidgets('약 이름 없이 저장하면 알려준다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('기록하기'));
    await tester.pump();

    expect(find.text('약 이름을 입력해주세요.'), findsOneWidget);
  });

  testWidgets('기록이 없으면 반복 카드를 띄우지 않는다', (tester) async {
    // 셀 것이 없는데 "반복된 것" 칸이 비어 있으면 고장으로 보입니다.
    await pump(tester);

    expect(find.textContaining('반복된 것'), findsNothing);
  });

  testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: CareRecordPage(),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
