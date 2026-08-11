import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/widgets/record_save_button.dart';

/// 기록 화면 아래 버튼이 한 곳에서 나오는지 확인합니다.
///
/// 예전에는 화면마다 같은 버튼을 30줄씩 들고 있었고, 체온만 `ButtonStyle`을
/// 쓰는 식으로 미묘하게 갈려 있었습니다.
void main() {
  group('동작', () {
    testWidgets('저장 중에는 눌리지 않는다', (tester) async {
      // 두 번 눌러 두 건이 들어가는 일을 막습니다.
      var taps = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordSaveButton(onPressed: () => taps++, saving: true),
        ),
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('기록하기'), findsNothing);
    });

    testWidgets('저장 중이 아니면 눌린다', (tester) async {
      var taps = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordSaveButton(onPressed: () => taps++, saving: false),
        ),
      ));

      await tester.tap(find.text('기록하기'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('다른 말이 필요한 화면은 라벨을 바꾼다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecordSaveButton(
            onPressed: () {},
            saving: false,
            label: '분석하기',
          ),
        ),
      ));

      expect(find.text('분석하기'), findsOneWidget);
    });
  });

  test('기록 화면이 저장 버튼을 직접 만들지 않는다', () {
    // 높이 60짜리 ElevatedButton은 이 버튼의 모양입니다. 직접 만들면
    // 색과 모서리가 다시 갈립니다.
    const allowed = {
      // 이 버튼은 사진이 없으면 비활성화되고 결과에 따라 색이 바뀝니다.
      // RecordSaveButton은 저장 중 여부만 받으므로 표현할 수 없습니다.
      'lib/features/detail/skin_analysis_page.dart',
      'lib/features/detail/widgets/record_save_button.dart',
    };

    final offenders = Directory('lib/features/detail')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final source = f.readAsStringSync();
          return source.contains('height: 60,') &&
              source.contains('child: ElevatedButton(');
        })
        .map((f) => f.path)
        .where((p) => !allowed.contains(p))
        .toList()
      ..sort();

    expect(offenders, isEmpty,
        reason: 'RecordSaveButton을 쓰거나, 왜 못 쓰는지 이 테스트의 목록에 적어 주세요.\n'
            '${offenders.join('\n')}');
  });
}
