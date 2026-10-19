import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/theme/app_theme.dart';
import 'package:flutter_project/features/contents/content_list_page.dart';
import 'package:flutter_project/features/contents/content_models.dart';
import 'package:flutter_project/features/contents/content_service.dart';

/// 공지 화면이 실패와 없음을 구별하는지.
///
/// 조회 실패를 빈 목록으로 접으면 "아직 글이 없다"가 되어, 있는 공지를
/// 없다고 말하게 됩니다. 이 저장소가 기록·상담에서 지켜 온 것과 같은
/// 원칙입니다 — 없는 것과 못 읽은 것은 다른 말입니다.
void main() {
  Future<void> pump(WidgetTester tester, ContentLoad load) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: ContentListPage(category: ContentCategory.notice, load: load),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('조회 실패는 실패로 말하고 다시 시도를 준다', (tester) async {
    await pump(tester, () async => throw Exception('network'));

    expect(find.textContaining('불러오지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('아직 올라온 글이 없습니다.'), findsNothing,
        reason: '실패를 없음으로 접으면 있는 공지를 없다고 말합니다');
  });

  testWidgets('빈 목록은 없음으로 말한다', (tester) async {
    await pump(tester, () async => const []);

    expect(find.text('아직 올라온 글이 없습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('다시 시도가 실제로 다시 읽는다', (tester) async {
    var calls = 0;
    await pump(tester, () async {
      calls++;
      if (calls == 1) throw Exception('network');
      return const [
        Content(id: 'c1', title: '9월 업데이트 안내', blocks: []),
      ];
    });

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('9월 업데이트 안내'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('새로고침 실패가 보던 목록을 지우지 않는다', (tester) async {
    // 당겨서 새로고침 중 망이 끊기면, 멀쩡히 읽던 목록을 오류 화면에
    // 내주지 않고 그대로 둡니다 — 커뮤니티 탭이 같은 실수를 고친 적이
    // 있습니다.
    var calls = 0;
    await pump(tester, () async {
      calls++;
      if (calls == 1) {
        return const [Content(id: 'c1', title: '9월 업데이트 안내', blocks: [])];
      }
      throw Exception('network');
    });
    expect(find.text('9월 업데이트 안내'), findsOneWidget);

    await tester.fling(find.text('9월 업데이트 안내'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('9월 업데이트 안내'), findsOneWidget,
        reason: '새로고침 실패가 보던 목록을 지우면 안 됩니다');
    expect(find.textContaining('불러오지 못했습니다'), findsNothing);
  });

  testWidgets('글을 누르면 본문이 블록으로 그려진다', (tester) async {
    await pump(tester, () async => const [
          Content(id: 'c1', title: '이유식 시작하기', blocks: [
            ContentBlock(type: 'paragraph', props: {'text': '생후 6개월부터 권장됩니다.'}),
          ]),
        ]);

    await tester.tap(find.text('이유식 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('생후 6개월부터 권장됩니다.'), findsOneWidget);
  });
}
