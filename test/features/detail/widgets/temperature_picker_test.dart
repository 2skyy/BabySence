import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/widgets/temperature_picker.dart';

/// 체온 선택기 동작과 모양을 확인합니다.
///
/// 골든 이미지는 `flutter test --update-goldens`로 갱신합니다.
/// 나이에 따라 구간 경계가 달라지므로 연령대별로 따로 남깁니다.
void main() {
  Widget wrap({
    required double value,
    int? ageInMonths,
    ValueChanged<double>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TemperaturePicker(
              value: value,
              ageInMonths: ageInMonths,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('판정 표시', () {
    testWidgets('정상 범위면 정상으로 보여준다', (tester) async {
      await tester.pumpWidget(wrap(value: 36.8, ageInMonths: 8));
      expect(find.text('36.8℃'), findsOneWidget);
      expect(find.text('정상'), findsOneWidget);
    });

    testWidgets('같은 38.2℃라도 나이에 따라 판정이 다르다', (tester) async {
      // 3개월 미만은 38.0℃부터 상담 권장입니다.
      await tester.pumpWidget(wrap(value: 38.2, ageInMonths: 1));
      expect(find.text('상담 권장'), findsOneWidget);

      // 6개월 이상은 39.0℃부터입니다.
      await tester.pumpWidget(wrap(value: 38.2, ageInMonths: 8));
      expect(find.text('주의'), findsOneWidget);
    });

    testWidgets('나이를 모르면 판정 대신 안내를 보여준다', (tester) async {
      await tester.pumpWidget(wrap(value: 38.2));
      expect(find.textContaining('아이 정보를 등록하면'), findsOneWidget);
      expect(find.text('주의'), findsNothing);
      expect(find.text('상담 권장'), findsNothing);
    });
  });

  group('± 버튼', () {
    testWidgets('0.1℃씩 조절한다', (tester) async {
      double current = 36.8;
      await tester.pumpWidget(wrap(
        value: current,
        ageInMonths: 8,
        onChanged: (v) => current = v,
      ));

      await tester.tap(find.byIcon(Icons.add));
      expect(current, closeTo(36.9, 1e-9));

      await tester.tap(find.byIcon(Icons.remove));
      expect(current, closeTo(36.7, 1e-9));
    });

    testWidgets('범위를 벗어나지 않는다', (tester) async {
      double current = TemperaturePicker.maxTemp;
      await tester.pumpWidget(wrap(
        value: current,
        ageInMonths: 8,
        onChanged: (v) => current = v,
      ));

      await tester.tap(find.byIcon(Icons.add));
      expect(current, TemperaturePicker.maxTemp);
    });
  });

  group('snap', () {
    test('0.1 단위로 맞추고 범위로 자른다', () {
      expect(TemperaturePicker.snap(36.84), 36.8);
      expect(TemperaturePicker.snap(36.86), 36.9);
      expect(TemperaturePicker.snap(10.0), TemperaturePicker.minTemp);
      expect(TemperaturePicker.snap(99.0), TemperaturePicker.maxTemp);
    });
  });

  group('골든', () {
    testWidgets('0~3개월 · 주의', (tester) async {
      await tester.pumpWidget(wrap(value: 37.8, ageInMonths: 1));
      await expectLater(
        find.byType(TemperaturePicker),
        matchesGoldenFile('goldens/temperature_picker_0to3m_caution.png'),
      );
    });

    testWidgets('6개월 이상 · 정상', (tester) async {
      await tester.pumpWidget(wrap(value: 36.8, ageInMonths: 8));
      await expectLater(
        find.byType(TemperaturePicker),
        matchesGoldenFile('goldens/temperature_picker_6m_normal.png'),
      );
    });

    testWidgets('6개월 이상 · 상담 권장', (tester) async {
      await tester.pumpWidget(wrap(value: 39.4, ageInMonths: 8));
      await expectLater(
        find.byType(TemperaturePicker),
        matchesGoldenFile('goldens/temperature_picker_6m_consult.png'),
      );
    });

    testWidgets('나이 모름', (tester) async {
      await tester.pumpWidget(wrap(value: 36.5));
      await expectLater(
        find.byType(TemperaturePicker),
        matchesGoldenFile('goldens/temperature_picker_unknown_age.png'),
      );
    });
  });
}
