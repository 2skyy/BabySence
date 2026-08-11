import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/widgets/medical_disclaimer.dart';

void main() {
  group('고지 문구', () {
    test('의료기기가 아니라고 분명히 말한다', () {
      expect(MedicalDisclaimer.fullText, contains('의료기기가 아닙니다'));
      expect(MedicalDisclaimer.shortText, contains('의료기기가 아니'));
    });

    test('진단을 대신하지 않는다고 말한다', () {
      expect(MedicalDisclaimer.fullText, contains('진단을 대신하지 않습니다'));
    });

    test('걱정되면 진료를 받으라고 안내한다', () {
      // 고지만 하고 다음 행동을 알려주지 않으면 쓸모가 없습니다.
      expect(MedicalDisclaimer.fullText, contains('소아과 진료'));
    });

    testWidgets('기본형은 전체 문구를 보여준다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MedicalDisclaimer()),
      ));

      expect(find.text(MedicalDisclaimer.fullText), findsOneWidget);
    });

    testWidgets('compact는 한 줄만 보여준다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MedicalDisclaimer(compact: true)),
      ));

      expect(find.text(MedicalDisclaimer.shortText), findsOneWidget);
      expect(find.text(MedicalDisclaimer.fullText), findsNothing);
    });

    testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(body: MedicalDisclaimer()),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}

// 각 화면에 고지가 실제로 붙어 있는지는 Supabase 없이 확인할 수 없습니다
// (조회가 실패하면 본문이 안내로 대체되어 고지도 그려지지 않습니다).
// 실기기에서 체온 판정·피부 분석·분석 탭을 열어 눈으로 확인해야 합니다.
