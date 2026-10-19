import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_project/core/theme/theme_controller.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 8, 11, hour, minute);

  group('어두울 시간인가', () {
    test('오후 6시부터 어둡다', () {
      expect(isDarkHour(at(17, 59)), isFalse);
      expect(isDarkHour(at(18, 0)), isTrue);
      expect(isDarkHour(at(23, 59)), isTrue);
    });

    test('자정을 넘어서도 어둡다', () {
      // 18시부터 6시까지는 날짜가 바뀝니다. `>= 18 && < 6`으로 쓰면
      // 항상 거짓이 되어 밤새 밝은 화면이 됩니다.
      expect(isDarkHour(at(0, 0)), isTrue);
      expect(isDarkHour(at(3, 30)), isTrue);
      expect(isDarkHour(at(5, 59)), isTrue);
    });

    test('오전 6시부터 밝다', () {
      expect(isDarkHour(at(6, 0)), isFalse);
      expect(isDarkHour(at(12, 0)), isFalse);
    });
  });

  group('설정에 따른 테마', () {
    test('자동은 시각을 따른다', () {
      expect(resolveThemeMode(ThemePreference.auto, at(20)), ThemeMode.dark);
      expect(resolveThemeMode(ThemePreference.auto, at(9)), ThemeMode.light);
    });

    test('고정은 시각을 무시한다', () {
      // 낮이어도 어둡게, 밤이어도 밝게.
      expect(
        resolveThemeMode(ThemePreference.alwaysDark, at(9)),
        ThemeMode.dark,
      );
      expect(
        resolveThemeMode(ThemePreference.alwaysLight, at(23)),
        ThemeMode.light,
      );
    });
  });

  group('다음 전환까지', () {
    test('낮이면 오후 6시까지 기다린다', () {
      expect(untilNextSwitch(at(9)), const Duration(hours: 9));
      expect(untilNextSwitch(at(17, 30)), const Duration(minutes: 30));
    });

    test('밤이면 오전 6시까지 기다린다', () {
      expect(untilNextSwitch(at(20)), const Duration(hours: 10));
      expect(untilNextSwitch(at(5, 45)), const Duration(minutes: 15));
    });

    test('자정을 넘겨 계산한다', () {
      // 23시에는 다음 날 6시까지 7시간입니다. 같은 날 6시로 계산하면
      // 음수가 되어 타이머가 즉시 터집니다.
      expect(untilNextSwitch(at(23)), const Duration(hours: 7));
    });

    test('경계 시각에서는 다음 경계로 넘어간다', () {
      // 정확히 18시면 이미 어두우므로 다음은 오전 6시입니다.
      expect(untilNextSwitch(at(18)), const Duration(hours: 12));
      // 정확히 6시면 이미 밝으므로 다음은 오후 6시입니다.
      expect(untilNextSwitch(at(6)), const Duration(hours: 12));
    });

    test('항상 양수다', () {
      // 0이나 음수면 타이머가 즉시 되풀이돼 무한 루프가 됩니다.
      for (var h = 0; h < 24; h++) {
        for (final m in [0, 1, 59]) {
          expect(
            untilNextSwitch(at(h, m)).inSeconds,
            greaterThan(0),
            reason: '$h:$m',
          );
        }
      }
    });
  });

  group('컨트롤러', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // 실기기 저장소가 없으므로 빈 값으로 시작합니다.
      SharedPreferences.setMockInitialValues({});
    });

    test('기본값은 자동', () async {
      final c = ThemeController();
      addTearDown(c.dispose);

      await c.load();
      expect(c.isAuto, isTrue);
    });

    test('자동을 끄면 지금 보이는 밝기를 그대로 굳힌다', () async {
      // 끄자마자 화면이 뒤집히면 사용자가 당황합니다.
      final c = ThemeController();
      addTearDown(c.dispose);
      await c.load();

      final wasDark = c.isDark;
      await c.setAuto(false);

      expect(c.isAuto, isFalse);
      expect(c.isDark, wasDark);
    });

    test('수동 선택은 시각과 무관하게 유지된다', () async {
      final c = ThemeController();
      addTearDown(c.dispose);
      await c.load();

      await c.setDark(true);
      expect(c.mode, ThemeMode.dark);
      expect(c.isAuto, isFalse);

      await c.setDark(false);
      expect(c.mode, ThemeMode.light);
    });

    test('설정이 저장되고 다시 읽힌다', () async {
      final first = ThemeController();
      await first.load();
      await first.setDark(true);
      first.dispose();

      final second = ThemeController();
      addTearDown(second.dispose);
      await second.load();

      expect(second.preference, ThemePreference.alwaysDark);
    });

    test('알 수 없는 저장값은 자동으로 떨어진다', () async {
      // 나중에 enum 이름을 바꾸면 옛 값이 남습니다. 그때 앱이 죽으면 안 됩니다.
      SharedPreferences.setMockInitialValues({'theme_preference': '없는값'});

      final c = ThemeController();
      addTearDown(c.dispose);
      await c.load();

      expect(c.isAuto, isTrue);
    });
  });
}
