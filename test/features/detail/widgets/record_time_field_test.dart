import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/widgets/record_time_field.dart';
import 'package:flutter_project/features/detail/widgets/time_picker_box.dart';

void main() {
  group('입력값을 시각으로', () {
    final now = DateTime(2026, 8, 8, 15, 0);

    RecordTimeController at(String period, String hour, String minute) {
      final c = RecordTimeController.now(DateTime(2026, 8, 8, 1, 1));
      c.period = period;
      c.hour.text = hour;
      c.minute.text = minute;
      return c;
    }

    test('오전·오후를 24시간제로 바꾼다', () {
      expect(at('오전', '09', '30').toDateTime(now), DateTime(2026, 8, 8, 9, 30));
      expect(at('오후', '01', '05').toDateTime(now), DateTime(2026, 8, 8, 13, 5));
    });

    test('오전 12시는 자정, 오후 12시는 정오', () {
      expect(at('오전', '12', '10').toDateTime(now), DateTime(2026, 8, 8, 0, 10));
      expect(at('오후', '12', '10').toDateTime(now), DateTime(2026, 8, 8, 12, 10));
    });

    test('미래가 되면 어제로 본다', () {
      // 자정 직후에 전날 일을 기록하는 경우입니다.
      final justAfterMidnight = DateTime(2026, 8, 8, 0, 10);
      expect(
        at('오후', '11', '30').toDateTime(justAfterMidnight),
        DateTime(2026, 8, 7, 23, 30),
      );
    });

    test('지금과 같은 시각은 어제로 밀지 않는다', () {
      // isAfter 경계. 같은 시각까지 어제로 보내면 방금 일이 하루 전이 됩니다.
      expect(at('오후', '03', '00').toDateTime(now), DateTime(2026, 8, 8, 15, 0));
    });

    test('범위를 벗어나거나 비면 null', () {
      expect(at('오전', '', '30').toDateTime(now), isNull);
      expect(at('오전', '0', '30').toDateTime(now), isNull);
      expect(at('오전', '13', '30').toDateTime(now), isNull);
      expect(at('오전', '09', '60').toDateTime(now), isNull);
    });
  });

  group('컨트롤러', () {
    test('지금 시각으로 시작한다', () {
      final c = RecordTimeController.now(DateTime(2026, 8, 8, 14, 7));
      expect(c.period, '오후');
      expect(c.hour.text, '02');
      expect(c.minute.text, '07');
    });

    test('setNow로 되돌린다', () {
      final c = RecordTimeController.now(DateTime(2026, 8, 8, 9, 0));
      c.hour.text = '11';
      c.setNow(DateTime(2026, 8, 8, 20, 45));

      expect(c.period, '오후');
      expect(c.hour.text, '08');
      expect(c.minute.text, '45');
    });
  });

  group('화면', () {
    testWidgets('라벨과 지금 버튼을 보여준다', (tester) async {
      final c = RecordTimeController.now(DateTime(2026, 8, 8, 9, 5));
      addTearDown(c.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordTimeField(
            label: '수유 시간',
            controller: c,
            onChanged: () {},
          ),
        ),
      ));

      expect(find.text('수유 시간'), findsOneWidget);
      expect(find.text('지금'), findsOneWidget);
      expect(find.text('오전 9:05'), findsOneWidget);
    });

    testWidgets('누르면 시간 선택기가 열린다', (tester) async {
      // 예전에는 오전/오후 칩과 시·분 칸 두 개를 각각 눌러 고쳐야 했습니다.
      final c = RecordTimeController.now(DateTime(2026, 8, 8, 9, 5));
      addTearDown(c.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordTimeField(
            label: '측정 시간',
            controller: c,
            onChanged: () {},
          ),
        ),
      ));

      await tester.tap(find.byType(TimePickerBox));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final c = RecordTimeController.now(DateTime(2026, 8, 8, 9, 5));
      addTearDown(c.dispose);

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: RecordTimeField(
              label: '교체 시간',
              controller: c,
              onChanged: () {},
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
