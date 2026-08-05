import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/analysis/analysis_page.dart';
import 'package:flutter_project/features/records/records_page.dart';

/// Supabase를 초기화하지 않고 띄웁니다.
///
/// 조회는 실패하지만, 그 실패를 화면이 삼키고 안내로 바꾸는지 확인합니다.
/// 서버가 죽었을 때 앱이 빈 화면이 되거나 터지면 안 됩니다.
void main() {
  Future<void> pump(WidgetTester tester, Widget page,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('기록 탭', () {
    testWidgets('기록 종류 5개를 모두 보여준다', (tester) async {
      await pump(tester, const RecordsPage());

      for (final label in ['수유', '배변', '수면', '체온', '예방접종']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('조회에 실패해도 터지지 않고 안내한다', (tester) async {
      await pump(tester, const RecordsPage());

      expect(tester.takeException(), isNull);
      expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
      // 바로가기가 3열 격자라 글자가 커지면 눌리기 쉽습니다.
      await pump(tester, const RecordsPage(), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('분석 탭', () {
    testWidgets('조회에 실패해도 터지지 않고 안내한다', (tester) async {
      await pump(tester, const AnalysisPage());

      expect(tester.takeException(), isNull);
      expect(find.text('분석을 불러오지 못했습니다.'), findsOneWidget);
    });

    testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
      await pump(tester, const AnalysisPage(), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
