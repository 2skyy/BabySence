import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/widgets/common_app_bar.dart';
import 'package:flutter_project/features/advice/ask_action.dart';
import 'package:flutter_project/features/advice/ask_fab.dart';
import 'package:flutter_project/features/detail/assessment/assessment.dart';

/// 상담으로 가는 길을 어디에 둘지 두 번 틀렸습니다.
///
/// 1. 각 기록 화면 한가운데 전면 버튼 — 기록하러 들어온 사람의 눈길을
///    계속 끌었습니다.
/// 2. 각 기록 화면 앱바의 작은 말풍선 아이콘 — 이번에는 **아무도 못
///    찾았습니다.** 있는지조차 몰랐습니다.
///
/// 두 실패의 공통점은 자리를 **기록 화면 안에서** 찾으려 한 것입니다.
/// 기록하는 중에 눈에 띄면 방해가 되고, 방해가 안 되면 안 보입니다.
///
/// 지금은 홈 오른쪽 아래에 하나 둡니다. 홈은 기록하러 들어가기 전에 머무는
/// 곳이라 눈에 띄어도 하던 일을 가로막지 않습니다.
///
/// 기록 화면의 아이콘은 **판정을 실어 보내는 셋만** 남겼습니다. 그건
/// "체온에 대해 묻기"가 아니라 "방금 나온 이 판정을 설명해 줘"라서, 홈에서는
/// 만들 수 없는 대화입니다.
void main() {
  group('홈 단추', () {
    testWidgets('누르면 종합 상담이 열린다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(floatingActionButton: AskFab()),
      ));

      await tester.tap(find.byType(AskFab));
      await tester.pumpAndSettle();

      expect(find.text('종합 상담'), findsOneWidget);
    });

    testWidgets('읽어 주는 이름이 있다', (tester) async {
      // 그림만 있는 단추라 화면 낭독기에는 아무 말도 안 됩니다.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(floatingActionButton: AskFab()),
      ));

      expect(
        find.bySemanticsLabel('아이에 대해 물어보기'),
        findsOneWidget,
      );
    });

    test('홈이 마지막 카드를 가리지 않게 비워 둔다', () {
      // 떠 있는 단추는 스크롤한 내용의 마지막 줄을 덮습니다.
      final home = File('lib/features/home/home_page.dart').readAsStringSync();
      expect(home.contains('AskFab.reservedHeight'), isTrue);
      expect(home.contains('floatingActionButton: const AskFab()'), isTrue);
    });
  });

  group('판정을 실어 보내는 곳만 남긴다', () {
    /// 이 셋은 "방금 나온 이 결과"를 대화의 출발점으로 넘깁니다.
    /// 홈에서 여는 종합 상담은 그 판정을 알 수 없습니다.
    const withAssessment = {
      'lib/features/detail/temperature_record_page.dart': '체온',
      'lib/features/detail/growth/growth_record_page.dart': '성장',
      'lib/features/detail/noise_result_page.dart': '소음 결과',
    };

    withAssessment.forEach((path, label) {
      test('$label 화면이 판정을 넘긴다', () {
        final source = File(path).readAsStringSync();
        expect(source.contains('AskAction('), isTrue);
        expect(source.contains('assessment:'), isTrue,
            reason: '판정을 안 넘길 거면 이 아이콘도 없애야 합니다');
      });
    });

    /// 영역 이름만 있던 아이콘들. 홈 단추가 같은 일을 합니다.
    const removed = [
      'lib/features/detail/feeding_record_page.dart',
      'lib/features/detail/diaper_record_page.dart',
      'lib/features/detail/sleep_record_page.dart',
      'lib/features/detail/care/care_record_page.dart',
      'lib/features/detail/vaccination_page.dart',
      'lib/features/analysis/analysis_page.dart',
    ];

    for (final path in removed) {
      test('${path.split('/').last} 에는 없다', () {
        expect(File(path).readAsStringSync().contains('AskAction('), isFalse,
            reason: '홈 단추와 겹칩니다');
      });
    }
  });

  group('아이콘 자체', () {
    testWidgets('영역 이름을 길게 누르면 보여준다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          appBar: CommonAppBar(
            title: '체온 기록',
            actions: [AskAction(domain: AssessmentDomain.temperature)],
          ),
        ),
      ));

      final button = tester.widget<IconButton>(find.byType(IconButton).last);
      expect(button.tooltip, '체온에 대해 물어보기');
    });

    testWidgets('누르면 그 영역의 대화가 열린다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AskAction(domain: AssessmentDomain.growth)),
      ));

      await tester.tap(find.byType(AskAction));
      await tester.pumpAndSettle();

      expect(find.text('성장 상담'), findsOneWidget);
    });
  });

  test('상담 화면을 각자 다시 만들지 않는다', () {
    // 화면마다 만들면 모양과 문구가 갈립니다.
    final offenders = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // ChatPage를 정의하고 여는 곳들입니다.
        .where((f) => !f.path.endsWith('ask_action.dart'))
        .where((f) => !f.path.endsWith('ask_fab.dart'))
        .where((f) => !f.path.endsWith('chat_page.dart'))
        .where((f) => f.readAsStringSync().contains('ChatPage('))
        .map((f) => f.path)
        .toList()
      ..sort();

    expect(offenders, isEmpty,
        reason: 'AskAction이나 AskFab을 쓰세요.\n${offenders.join('\n')}');
  });
}
