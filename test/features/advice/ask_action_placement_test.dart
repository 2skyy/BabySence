import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/widgets/common_app_bar.dart';
import 'package:flutter_project/features/advice/ask_action.dart';
import 'package:flutter_project/features/advice/ask_fab.dart';
import 'package:flutter_project/features/detail/assessment/assessment.dart';

/// 상담으로 가는 길을 어디에 둘지 세 번 옮겼습니다.
///
/// 1. 각 기록 화면 한가운데 전면 버튼 — 기록하러 들어온 사람의 눈길을
///    계속 끌었습니다.
/// 2. 각 기록 화면 앱바의 작은 말풍선 아이콘 — 이번에는 **아무도 못
///    찾았습니다.** 있는지조차 몰랐습니다.
/// 3. 판정을 넘기는 셋만 남김 — 여전히 화면마다 있는 셈이었습니다.
///
/// 지금은 **홈 오른쪽 아래 단추 하나뿐**입니다. 홈은 기록하러 들어가기
/// 전에 머무는 곳이라 눈에 띄어도 하던 일을 가로막지 않습니다.
///
/// 입구가 하나이므로 그 대화는 **무엇을 물어도 답할 수 있어야** 합니다.
/// 그래서 종합 맥락이 체온·수유·배변·수면·약병원을 전부 담습니다.
///
/// [AskAction] 자체는 남겨 둡니다 — 지금은 쓰이지 않지만 판정 결과에서
/// 다시 열고 싶어질 수 있고, 그때 화면마다 새로 만들지 않게 하려는 것입니다.
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

  group('기록 화면에는 두지 않는다', () {
    // 자리를 세 번 옮겼습니다.
    //
    //   1. 기록 화면 한가운데 전면 버튼 — 기록하러 온 사람의 눈길을 끔
    //   2. 기록 화면 앱바 아이콘 — 아무도 못 찾음
    //   3. 판정을 넘기는 셋만 남김 — 여전히 화면마다 있는 셈
    //
    // 지금은 **홈 단추 하나뿐**입니다. 입구가 하나여야 그 대화가 모든
    // 기록을 맥락으로 받는다는 약속이 성립합니다.
    const screens = [
      'lib/features/detail/temperature_record_page.dart',
      'lib/features/detail/feeding_record_page.dart',
      'lib/features/detail/diaper_record_page.dart',
      'lib/features/detail/sleep_record_page.dart',
      'lib/features/detail/growth/growth_record_page.dart',
      'lib/features/detail/care/care_record_page.dart',
      'lib/features/detail/vaccination_page.dart',
      'lib/features/detail/skin_analysis_page.dart',
      'lib/features/detail/noise_result_page.dart',
      'lib/features/analysis/analysis_page.dart',
    ];

    for (final path in screens) {
      test('${path.split('/').last} 에 없다', () {
        expect(File(path).readAsStringSync().contains('AskAction('), isFalse,
            reason: '상담 입구는 홈 단추 하나입니다');
      });
    }
  });

  group('홈 대화가 모든 기록을 받는다', () {
    // 입구가 하나뿐이므로 무엇을 물어도 답할 수 있어야 합니다. 예전에는
    // overall이 약·병원만 담아, "어젯밤 잘 잤나요"에 근거 없이 답했습니다.
    final context =
        File('lib/features/advice/chat_context.dart').readAsStringSync();

    test('종합이면 영역 전부를 담는다', () {
      expect(context.contains('_everything(baby.id)'), isTrue);
      final everything = context.substring(context.indexOf('_Everything> _everything('));
      for (final d in [
        'AssessmentDomain.temperature',
        'AssessmentDomain.feeding',
        'AssessmentDomain.diaper',
        'AssessmentDomain.sleep',
      ]) {
        expect(everything.contains(d), isTrue, reason: d);
      }
      expect(everything.contains("'약·병원'"), isTrue);
    });

    test('영역마다 건수를 줄여 맥락 상한을 넘기지 않는다', () {
      // 서버의 MAX_CONTEXT_CHARS는 2000자입니다. 다섯 영역에 5건씩이면
      // 뒤쪽 영역이 통째로 잘리는데, 잘린 것을 아무도 모릅니다.
      expect(context.contains('static const int overallLimit = 3;'), isTrue);
      expect(context.contains('limit: overallLimit'), isTrue);
    });

    test('한 영역이 실패해도 나머지는 담는다', () {
      // 실패한 영역만 빠지고 나머지는 그대로 갑니다.
      expect(context.contains('} else if (rows.isNotEmpty) {'), isTrue);
    });

    test('실패를 "기록 없음"과 구별해 화면에 전한다', () {
      // _recentFor가 실패에 빈 목록을 돌려주면 "없다"와 같은 말이 되고,
      // 모델이 없는 것을 없다고 확언합니다. 화면도 "아이 정보를 등록하면…"
      // 이라고 말했습니다 — 아이는 등록돼 있는데요.
      expect(context.contains('Future<List<String>?> _recentFor'), isTrue);
      expect(context.contains('class ChatContextResult'), isTrue);
      expect(context.contains('final bool failed;'), isTrue);

      final page =
          File('lib/features/advice/chat_page.dart').readAsStringSync();
      expect(page.contains('failed = result.failed;'), isTrue);
    });
  });

  group('맥락이 사실을 말한다', () {
    final context =
        File('lib/features/advice/chat_context.dart').readAsStringSync();
    final page = File('lib/features/advice/chat_page.dart').readAsStringSync();

    test('지금이 언제인지 밝힌다', () {
      // 없으면 아래 기록이 얼마나 지난 것인지 모델이 알 수 없습니다.
      expect(context.contains("lines.add('- 지금:"), isTrue);
    });

    test('기록 시각에 연도가 있다', () {
      // 화면용 formatRecordTime은 "2/14 오후 3:20"처럼 연도가 없습니다.
      // 사람이 훑을 때는 충분하지만, 모델에게는 반년 전 고열이 '최근
      // 체온 기록'으로 읽힙니다.
      expect(context.contains('formatRecordTime('), isFalse,
          reason: '맥락에는 _contextTime을 쓰세요');
      expect(context.contains('static String _contextTime('), isTrue);
      expect(context.contains(r"'${at.year}-"), isTrue);
    });

    test('맥락을 모으는 중에는 보내지 않는다', () {
      // 열어 두면 첫 질문이 아이 정보도 기록도 없이 나갑니다.
      expect(page.contains('(_waiting || _loadingContext) ? null : _send'),
          isTrue);
    });

    test('기다리는 사이 새로 적은 글을 덮지 않는다', () {
      expect(page.contains('if (_input.text.trim().isEmpty) _input.text = text;'),
          isTrue);
    });
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
