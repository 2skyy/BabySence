import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/home/home_page.dart';

/// 홈 타일이 **화면에** 세 상태를 구별해 보여주는지.
///
/// `test/silent_failure_test.dart`는 소스에 '불러오지 못함'·'기록 없음'
/// 문자열이 있는지만 봤습니다. 있긴 했습니다 — `_tileSubtitle`이 만들고
/// 있었으니까요. 그런데 타일이 그 값을 **받아 놓고 그리지 않아** 한 번도
/// 화면에 닿은 적이 없었습니다. 통과하는 테스트 옆에서 이 앱의 첫 번째
/// 원칙(실패와 없음을 구별한다)이 홈에서는 지켜지지 않고 있었습니다.
void main() {
  Future<void> pump(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: const MaterialApp(home: HomePage()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('조회에 실패하면 타일이 그렇게 말한다', (tester) async {
    // Supabase를 초기화하지 않았으므로 조회가 실패합니다.
    await pump(tester);

    expect(find.text('불러오지 못함'), findsWidgets,
        reason: '실패를 "기록 없음"과 같은 얼굴로 보여주면 안 됩니다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('부제목이 정해진 문구 중 하나다', (tester) async {
    await pump(tester);

    // 네 타일(수유·배변·수면·체온)은 상태에 따라 셋 중 하나를 씁니다.
    const states = ['불러오는 중…', '불러오지 못함', '기록 없음'];
    final shown = states.where((s) => find.text(s).evaluate().isNotEmpty);
    expect(shown, isNotEmpty, reason: '셋 중 아무것도 화면에 없습니다');
  });

  testWidgets('고정 부제목도 그려진다', (tester) async {
    // 소음·성장·피부·접종·약병원은 상태와 무관한 안내 문구를 답니다.
    await pump(tester);
    for (final label in ['측정하기', 'WHO 성장곡선', 'AI 판단', '접종 일정', '투약과 진료']) {
      expect(find.text(label), findsOneWidget, reason: '$label 이 안 보입니다');
    }
  });

  testWidgets('글자를 키워도 타일이 넘치지 않는다', (tester) async {
    // 부제목이 한 줄 늘었습니다. 3열 격자라 두 줄이 되면 넘칩니다.
    // 0.72로는 1.3배에서 9.7px 넘쳤습니다.
    for (final scale in [1.0, 1.3, 1.6]) {
      await pump(tester, textScale: scale);
      expect(tester.takeException(), isNull, reason: '배율 $scale 에서 넘칩니다');
    }
  });
}
