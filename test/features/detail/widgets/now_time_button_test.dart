import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/widgets/now_time_button.dart';

void main() {
  group('현재 시각을 입력칸 값으로', () {
    test('오전·오후를 나눈다', () {
      expect(nowTimeFields(DateTime(2026, 8, 8, 9, 5)).period, '오전');
      expect(nowTimeFields(DateTime(2026, 8, 8, 15, 5)).period, '오후');
    });

    test('자정은 오전 12시, 정오는 오후 12시', () {
      // 12시간제에서 0시를 '오전 00시'로 쓰면 시계에 없는 표기가 됩니다.
      final midnight = nowTimeFields(DateTime(2026, 8, 8, 0, 30));
      expect(midnight.period, '오전');
      expect(midnight.hour, '12');

      final noon = nowTimeFields(DateTime(2026, 8, 8, 12, 0));
      expect(noon.period, '오후');
      expect(noon.hour, '12');
    });

    test('오후 시각을 12시간제로 바꾼다', () {
      final t = nowTimeFields(DateTime(2026, 8, 8, 13, 7));
      expect(t.period, '오후');
      expect(t.hour, '01');
      expect(t.minute, '07');
    });

    test('두 자리로 채운다', () {
      // 한 자리로 두면 숫자 폭이 달라져 입력칸이 흔들립니다.
      final t = nowTimeFields(DateTime(2026, 8, 8, 8, 5));
      expect(t.hour, '08');
      expect(t.minute, '05');
    });

    test('인자가 없으면 지금을 쓴다', () {
      final before = DateTime.now();
      final t = nowTimeFields();
      final after = DateTime.now();

      // 실행 사이에 분이 바뀔 수 있어 양쪽 중 하나와 맞으면 됩니다.
      final candidates = {
        nowTimeFields(before).minute,
        nowTimeFields(after).minute,
      };
      expect(candidates, contains(t.minute));
    });
  });

  group('지금 버튼', () {
    testWidgets('누르면 콜백이 불린다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NowTimeButton(onPressed: () => pressed++),
        ),
      ));

      await tester.tap(find.text('지금'));
      await tester.pump();

      expect(pressed, 1);
    });

    testWidgets('무엇을 채우는지 툴팁으로 구분한다', (tester) async {
      // 수면 화면처럼 버튼이 둘일 때 어느 칸을 바꾸는지 알 수 있어야 합니다.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: NowTimeButton(onPressed: _noop, semanticLabel: '시작 시간'),
        ),
      ));

      expect(find.byTooltip('시작 시간을 지금으로'), findsOneWidget);
    });
  });
}

void _noop() {}
