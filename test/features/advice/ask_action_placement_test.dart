import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/widgets/common_app_bar.dart';
import 'package:flutter_project/features/advice/ask_action.dart';
import 'package:flutter_project/features/detail/assessment/assessment.dart';

/// 상담을 따로 모아 둔 탭 대신 **기록하던 자리**에 두기로 했습니다.
///
/// 체온을 재다 궁금해진 것은 체온에 대한 것입니다. 그때 화면을 옮겨 다시
/// 영역을 고르게 하면 묻기를 그만두게 됩니다.
///
/// 다만 화면 한가운데 전면 버튼으로 두니 기록하러 들어온 사람의 눈길을 계속
/// 끌었습니다. 그래서 앱바 오른쪽 아이콘으로 옮겼습니다.
void main() {
  group('아이콘', () {
    testWidgets('영역 이름을 길게 누르면 보여준다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          appBar: CommonAppBar(
            title: '수면 기록',
            actions: [AskAction(domain: AssessmentDomain.sleep)],
          ),
        ),
      ));

      final button = tester.widget<IconButton>(find.byType(IconButton).last);
      expect(button.tooltip, '수면에 대해 물어보기');
    });

    testWidgets('설명을 직접 줄 수 있다', (tester) async {
      // 영역 이름이 화면과 어긋나는 곳이 있습니다(예방접종은 domain이 overall).
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          appBar: CommonAppBar(
            title: '예방접종',
            actions: [
              AskAction(
                domain: AssessmentDomain.overall,
                tooltip: '예방접종에 대해 물어보기',
              ),
            ],
          ),
        ),
      ));

      final button = tester.widget<IconButton>(find.byType(IconButton).last);
      expect(button.tooltip, '예방접종에 대해 물어보기');
    });

    testWidgets('누르면 그 영역의 대화가 열린다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AskAction(domain: AssessmentDomain.diaper)),
      ));

      await tester.tap(find.byType(AskAction));
      await tester.pumpAndSettle();

      expect(find.text('배변 상담'), findsOneWidget);
    });
  });

  /// 하나라도 빠지면 그 화면에서는 물어볼 방법이 없습니다.
  const screens = {
    'lib/features/detail/temperature_record_page.dart': '체온',
    'lib/features/detail/feeding_record_page.dart': '수유',
    'lib/features/detail/diaper_record_page.dart': '배변',
    'lib/features/detail/sleep_record_page.dart': '수면',
    'lib/features/detail/growth/growth_record_page.dart': '성장',
    'lib/features/detail/care/care_record_page.dart': '약·병원',
    'lib/features/detail/vaccination_page.dart': '예방접종',
    'lib/features/detail/skin_analysis_page.dart': '피부',
    // 소음은 측정 화면이 아니라 결과 화면에 둡니다.
    'lib/features/detail/noise_result_page.dart': '소음',
    'lib/features/analysis/analysis_page.dart': '분석',
  };

  test('기록 화면마다 상담으로 가는 길이 있다', () {
    final missing = <String>[];
    screens.forEach((path, label) {
      if (!File(path).readAsStringSync().contains('AskAction(')) {
        missing.add('$label ($path)');
      }
    });

    expect(missing, isEmpty, reason: '상담 아이콘이 없습니다:\n${missing.join('\n')}');
  });

  test('앱바에 둔다 — 본문 한가운데가 아니라', () {
    // 본문에 두면 기록하는 동안 계속 눈에 들어옵니다. 앱바는 자리가 화면마다
    // 같고, 필요할 때 찾아 누르면 됩니다.
    final offenders = <String>[];
    screens.forEach((path, label) {
      final source = File(path).readAsStringSync();
      final appBar = source.indexOf('appBar:');
      final body = source.indexOf('body:', appBar);
      final action = source.indexOf('AskAction(');
      if (appBar < 0 || body < 0 || action < appBar || action > body) {
        offenders.add('$label ($path)');
      }
    });

    expect(offenders, isEmpty,
        reason: '앱바 actions로 옮기세요:\n${offenders.join('\n')}');
  });

  test('상담 버튼을 각자 다시 만들지 않는다', () {
    // 예전에는 체온 화면만 직접 만들어 두었습니다. 화면마다 만들면
    // 모양과 문구가 갈립니다.
    final offenders = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // 이 두 파일은 ChatPage를 정의하고 여는 곳입니다.
        .where((f) => !f.path.endsWith('ask_action.dart'))
        .where((f) => !f.path.endsWith('chat_page.dart'))
        .where((f) => f.readAsStringSync().contains('ChatPage('))
        .map((f) => f.path)
        .toList()
      ..sort();

    expect(offenders, isEmpty,
        reason: 'AskAction을 쓰세요.\n${offenders.join('\n')}');
  });
}
