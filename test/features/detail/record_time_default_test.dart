import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/diaper_record_page.dart';
import 'package:flutter_project/features/detail/feeding_record_page.dart';
import 'package:flutter_project/features/detail/temperature_record_page.dart';
import 'package:flutter_project/features/detail/widgets/now_time_button.dart';
import 'package:flutter_project/features/detail/widgets/record_time_field.dart';
import 'package:flutter_project/features/detail/widgets/time_picker_box.dart';

/// Supabase 없이 띄웁니다. 이력 조회는 실패하지만 입력 부분은 그려집니다.
///
/// 수유·배변·체온 세 화면이 같은 규칙을 따르는지 한자리에서 봅니다.
/// 수면은 취침·기상이 몇 시간 떨어져 있어 기본값을 지금으로 두면 길이 0인
/// 기록이 되므로 일부러 제외했습니다.
void main() {
  final screens = <String, Widget Function()>{
    '수유': () => const FeedingRecordPage(),
    '배변': () => const DiaperRecordPage(),
    '체온': () => const TemperatureRecordPage(),
  };

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
  }

  screens.forEach((name, build) {
    testWidgets('$name 화면은 지금 시각으로 열린다', (tester) async {
      // 예전에는 배변이 08:40으로 고정돼 있었고, 수유·체온은 시간을 아예
      // 고칠 수 없었습니다.
      //
      // 화면이 시각을 읽는 순간과 여기서 확인하는 순간 사이에 분이 바뀔 수
      // 있습니다. 한쪽만 보면 몇 백 번에 한 번 애먼 실패가 납니다.
      final before = TimeOfDay.now();
      await pump(tester, build());
      final after = TimeOfDay.now();

      final shown = [
        for (final t in {
          TimePickerBox.format(before),
          TimePickerBox.format(after),
        })
          if (find.text(t).evaluate().isNotEmpty) t,
      ];

      expect(shown, isNotEmpty, reason: '$name — ${TimePickerBox.format(after)}');
    });

    testWidgets('$name 화면에 시간 입력과 지금 버튼이 있다', (tester) async {
      await pump(tester, build());

      expect(find.byType(RecordTimeField), findsOneWidget, reason: name);
      expect(find.byType(NowTimeButton), findsOneWidget, reason: name);
    });

    testWidgets('$name 시간을 누르면 선택기가 열린다', (tester) async {
      // 예전에는 오전/오후를 누르고 시·분을 각각 타이핑해야 했습니다.
      await pump(tester, build());

      await tester.tap(find.byType(TimePickerBox));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget, reason: name);
    });
  });
}
