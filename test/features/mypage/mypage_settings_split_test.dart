import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_project/core/theme/theme_controller.dart';
import 'package:flutter_project/features/settings/settings_page.dart';

/// 마이페이지와 설정의 역할이 다시 뒤섞이지 않게 고정합니다.
///
/// 예전에는 두 화면이 같은 항목을 나눠 갖고 있었습니다. 마이페이지에
/// 'Settings'가 있고 설정에 'Edit Profile'이 있어, 어디로 가야 할지
/// 알기 어려웠습니다.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pushed(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 실제 앱은 MaterialApp을 ThemeScope로 감쌉니다. 설정 화면의 다크 모드
    // 항목이 컨트롤러를 찾지 못하면 숨겨지므로 똑같이 감싸 줍니다.
    final theme = ThemeController();
    addTearDown(theme.dispose);

    await tester.pumpWidget(ThemeScope(
      controller: theme,
      child: MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  group('설정', () {
    testWidgets('뒤로가기 버튼이 있다', (tester) async {
      await pushed(tester, const SettingsPage());
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('앱 동작 설정만 담는다', (tester) async {
      await pushed(tester, const SettingsPage());

      expect(find.text('설정'), findsOneWidget);
      expect(find.text('기록 알림'), findsOneWidget);
      expect(find.text('다크 모드'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
    });

    testWidgets('내 정보·아이 항목은 두지 않는다', (tester) async {
      // 이것들은 마이페이지 몫입니다.
      await pushed(tester, const SettingsPage());

      expect(find.text('내 정보'), findsNothing);
      expect(find.text('아이'), findsNothing);
      expect(find.text('함께 키우기'), findsNothing);
    });

    testWidgets('스위치는 다크 모드 두 개뿐이고 실제로 동작한다', (tester) async {
      // 예전에는 켜고 끌 수 있어 보이지만 아무것도 저장되지 않는 스위치가
      // 있었습니다. 지금 있는 스위치는 실제로 테마를 바꿉니다.
      await pushed(tester, const SettingsPage());

      expect(find.byType(SwitchListTile), findsNWidgets(2));

      // 자동을 끄면 수동 스위치가 열립니다.
      await tester.tap(find.text('시간에 따라 자동'));
      await tester.pumpAndSettle();

      final manual = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '다크 모드'),
      );
      expect(manual.onChanged, isNotNull, reason: '자동을 끄면 직접 고를 수 있어야 합니다');
    });

    testWidgets('자동이 켜져 있으면 수동 스위치는 잠긴다', (tester) async {
      // 둘 다 만질 수 있으면 어느 쪽이 이기는지 알 수 없습니다.
      await pushed(tester, const SettingsPage());

      final manual = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '다크 모드'),
      );
      expect(manual.onChanged, isNull);
    });

    testWidgets('기록 알림은 아직 스위치가 아니다', (tester) async {
      // FCM 설정 파일이 없어 푸시 자체가 동작하지 않습니다. 스위치로 두면
      // 켤 수 있어 보입니다.
      await pushed(tester, const SettingsPage());

      expect(
        find.widgetWithText(SwitchListTile, '기록 알림'),
        findsNothing,
      );
    });

    testWidgets('로그아웃은 먼저 확인을 받는다', (tester) async {
      // 실수로 눌러 로그아웃되면 다시 로그인해야 합니다.
      await pushed(tester, const SettingsPage());

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();

      expect(find.text('로그아웃할까요?'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
    });

    testWidgets('알림을 누르면 준비 중 화면으로 간다', (tester) async {
      await pushed(tester, const SettingsPage());

      await tester.tap(find.text('기록 알림'));
      await tester.pumpAndSettle();

      expect(find.text('준비 중입니다'), findsOneWidget);
    });
  });
}
