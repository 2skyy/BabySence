import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/widgets/common_app_bar.dart';

/// 앱바를 한 곳에서 만드는지 확인합니다.
///
/// 예전에는 화면마다 `AppBar`를 직접 만들었습니다(19곳). 그 결과 뒤로가기
/// 화살표가 두 종류로 갈렸고, 흰 바탕이 박힌 곳이 남아 다크 모드에서 그
/// 화면만 밝게 떴습니다.
void main() {
  group('동작', () {
    Future<void> pumpPushed(WidgetTester tester, Widget appBarHost) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => appBarHost)),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('돌아갈 곳이 있으면 뒤로가기를 보여준다', (tester) async {
      await pumpPushed(
        tester,
        const Scaffold(appBar: CommonAppBar(title: '기록')),
      );

      expect(find.text('기록'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('돌아갈 곳이 없으면 두지 않는다', (tester) async {
      // 눌러도 아무 일이 없는 버튼은 고장으로 보입니다.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(appBar: CommonAppBar(title: '홈')),
      ));

      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    });

    testWidgets('showBack이 false면 두지 않는다', (tester) async {
      await pumpPushed(
        tester,
        const Scaffold(appBar: CommonAppBar(title: '온보딩', showBack: false)),
      );

      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    });

    testWidgets('뒤로가기를 누르면 돌아간다', (tester) async {
      await pumpPushed(
        tester,
        const Scaffold(appBar: CommonAppBar(title: '설정')),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('오른쪽 버튼을 받을 수 있다', (tester) async {
      await pumpPushed(
        tester,
        Scaffold(
          appBar: CommonAppBar(
            title: '게시글',
            actions: [IconButton(icon: const Icon(Icons.edit), onPressed: () {})],
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  group('앱 전체', () {
    test('제목만 있는 앱바를 직접 만들지 않는다', () {
      // 제목·뒤로가기만 있는 앱바는 CommonAppBar로 충분합니다. 직접 만들면
      // 색과 화살표가 다시 갈립니다.
      //
      // 로그인·회원가입·아이 등록·소음처럼 제목이 없거나 모양이 다른
      // 앱바는 대상이 아닙니다. 그런 화면은 아래 목록에 이유와 함께 둡니다.
      const allowed = {
        'lib/features/auth/login_page.dart',        // 제목 없음, 첫 화면이라 뒤로가기도 없음
        'lib/features/auth/signup_page.dart',       // 제목 없이 뒤로가기만
        'lib/features/onboarding/child_info_page.dart', // 제목 없이 '나중에 하기'만
        'lib/features/detail/noise_test_page.dart', // 측정 중에는 나가지 못하게 막습니다
      };

      final offenders = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('appBar: AppBar('))
          .map((f) => f.path)
          .where((p) => !allowed.contains(p))
          .toList()
        ..sort();

      expect(offenders, isEmpty,
          reason: 'CommonAppBar를 쓰거나, 왜 못 쓰는지 이 테스트의 목록에 적어 주세요.\n'
              '${offenders.join('\n')}');
    });
  });
}
