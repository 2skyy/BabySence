import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/theme/app_theme.dart';
import 'package:flutter_project/features/contents/content_blocks_view.dart';
import 'package:flutter_project/features/contents/content_models.dart';

/// 서버 콘텐츠가 앱을 깨뜨리지 못하는지.
///
/// 콘텐츠는 앱과 무관하게, 앱보다 자주 바뀝니다. 구버전 앱이 신버전
/// 콘텐츠(모르는 블록 type, 어긋난 모양)를 만나는 것은 예외가 아니라
/// **정상 운영**입니다 — 그때 죽으면 콘텐츠를 자유롭게 고칠 수 없게 되어
/// "심사 없이 반영"이라는 이 기능의 존재 이유가 사라집니다.
void main() {
  Future<void> pump(WidgetTester tester, List<ContentBlock> blocks) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: ContentBlocksView(blocks: blocks)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('아는 블록들을 그린다', (tester) async {
    await pump(tester, const [
      ContentBlock(type: 'heading', props: {'text': '9월 업데이트 안내'}),
      ContentBlock(type: 'paragraph', props: {'text': '수유 알림이 정확해졌습니다.'}),
      ContentBlock(type: 'alert', props: {'text': '앱을 최신으로 유지해 주세요.'}),
    ]);

    expect(find.text('9월 업데이트 안내'), findsOneWidget);
    expect(find.text('수유 알림이 정확해졌습니다.'), findsOneWidget);
    expect(find.text('앱을 최신으로 유지해 주세요.'), findsOneWidget);
  });

  testWidgets('모르는 type이 섞여도 죽지 않고 그 블록만 건너뛴다', (tester) async {
    // 신버전 앱을 위해 발행한 video 블록을 구버전 앱이 만난 상황.
    await pump(tester, const [
      ContentBlock(type: 'heading', props: {'text': '이유식 시작하기'}),
      ContentBlock(type: 'video', props: {'url': 'https://example.com/v.mp4'}),
      ContentBlock(type: 'paragraph', props: {'text': '생후 6개월부터 권장됩니다.'}),
    ]);

    expect(tester.takeException(), isNull,
        reason: '모르는 블록이 화면 전체를 죽이면 콘텐츠를 자유롭게 못 고칩니다');
    expect(find.text('이유식 시작하기'), findsOneWidget);
    expect(find.text('생후 6개월부터 권장됩니다.'), findsOneWidget);
  });

  testWidgets('모양이 어긋난 블록도 그 블록만 조용히 빠진다', (tester) async {
    await pump(tester, const [
      ContentBlock(type: 'heading'), // text 없음
      ContentBlock(type: 'paragraph', props: {'text': '본문은 그려집니다.'}),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('본문은 그려집니다.'), findsOneWidget);
  });

  group('블록 파싱도 같은 원칙을 지킨다', () {
    test('배열이 아니면 빈 목록', () {
      expect(ContentBlock.listFrom('오염된 값'), isEmpty);
      expect(ContentBlock.listFrom(null), isEmpty);
      expect(ContentBlock.listFrom({'type': 'heading'}), isEmpty);
    });

    test('블록 모양이 아닌 항목만 빠지고 나머지는 산다', () {
      final blocks = ContentBlock.listFrom([
        {'type': 'heading', 'props': {'text': '제목'}},
        '문자열 항목',
        {'props': {'text': 'type 없음'}},
        {'type': 42},
        {'type': 'paragraph'}, // props 없음 — 블록으로는 유효
      ]);

      expect(blocks, hasLength(2));
      expect(blocks[0].type, 'heading');
      expect(blocks[0].text('text'), '제목');
      expect(blocks[1].type, 'paragraph');
      expect(blocks[1].props, isEmpty);
    });
  });
}
