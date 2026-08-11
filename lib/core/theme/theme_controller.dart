import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면 밝기를 정하는 방식.
///
/// 이름이 그대로 저장되므로 바꾸면 기존 사용자의 설정이 초기화됩니다.
enum ThemePreference {
  /// 시각에 따라 자동으로 바뀝니다(기본값).
  auto,

  /// 항상 어둡게.
  alwaysDark,

  /// 항상 밝게.
  alwaysLight,
}

/// 자동 모드에서 어두워지기 시작하는 시각(24시간제).
const int darkStartHour = 18;

/// 자동 모드에서 다시 밝아지는 시각.
const int darkEndHour = 6;

/// 주어진 시각이 어두울 시간인지.
///
/// 18시부터 다음 날 6시까지가 어두운 구간입니다. 자정을 넘어가므로
/// `>= 18 || < 6` 형태가 됩니다 — `>= 18 && < 6`은 항상 거짓입니다.
///
/// 기기의 **현지 시각**을 씁니다. 한국 시간으로 고정하지 않은 이유는,
/// 사용자가 다른 시간대에 있을 때 그곳의 낮에 화면이 어두워지면 곤란하기
/// 때문입니다. 국내에서 쓰면 한국 시간과 같습니다.
bool isDarkHour(DateTime at) => at.hour >= darkStartHour || at.hour < darkEndHour;

/// 설정과 현재 시각으로 실제 적용할 테마를 정합니다.
ThemeMode resolveThemeMode(ThemePreference preference, DateTime now) {
  switch (preference) {
    case ThemePreference.alwaysDark:
      return ThemeMode.dark;
    case ThemePreference.alwaysLight:
      return ThemeMode.light;
    case ThemePreference.auto:
      return isDarkHour(now) ? ThemeMode.dark : ThemeMode.light;
  }
}

/// 다음 전환까지 남은 시간.
///
/// 앱을 켜 둔 채 18시나 6시를 넘기면 화면이 바뀌어야 합니다. 1분마다 깨워
/// 확인하는 대신, 다음 경계까지 한 번만 기다립니다.
Duration untilNextSwitch(DateTime now) {
  final nextHour = isDarkHour(now) ? darkEndHour : darkStartHour;

  var next = DateTime(now.year, now.month, now.day, nextHour);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

/// 테마 설정을 들고 있으면서 시각에 따라 스스로 바뀝니다.
///
/// `MaterialApp`이 이 값을 듣고 다시 그립니다.
class ThemeController extends ChangeNotifier {
  static const _storageKey = 'theme_preference';

  ThemePreference _preference = ThemePreference.auto;
  ThemeMode _mode = ThemeMode.light;
  Timer? _timer;

  ThemePreference get preference => _preference;
  ThemeMode get mode => _mode;

  /// 자동 모드인지. 설정 화면의 첫 번째 스위치가 이 값을 씁니다.
  bool get isAuto => _preference == ThemePreference.auto;

  /// 지금 어두운 상태인지. 자동이면 시각에 따라 달라집니다.
  bool get isDark => _mode == ThemeMode.dark;

  /// 저장된 설정을 읽고 현재 시각에 맞춥니다.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    _preference = ThemePreference.values.firstWhere(
      (p) => p.name == saved,
      // 저장된 값이 없거나 알 수 없는 값이면 자동으로 둡니다.
      orElse: () => ThemePreference.auto,
    );

    _apply();
  }

  Future<void> setPreference(ThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    _apply();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, preference.name);
  }

  /// 자동 켜기/끄기. 자동을 끄면 **지금 보이는 밝기를 그대로 굳힙니다.**
  /// 끄자마자 화면이 뒤집히면 사용자가 당황합니다.
  Future<void> setAuto(bool auto) {
    if (auto) return setPreference(ThemePreference.auto);
    return setPreference(
      isDark ? ThemePreference.alwaysDark : ThemePreference.alwaysLight,
    );
  }

  /// 수동 전환. 자동 모드에서 이걸 부르면 자동이 풀립니다.
  Future<void> setDark(bool dark) => setPreference(
        dark ? ThemePreference.alwaysDark : ThemePreference.alwaysLight,
      );

  void _apply() {
    _timer?.cancel();

    final now = DateTime.now();
    _mode = resolveThemeMode(_preference, now);

    // 자동일 때만 다음 경계를 기다립니다. 고정 모드는 시각과 무관합니다.
    if (_preference == ThemePreference.auto) {
      _timer = Timer(untilNextSwitch(now), _apply);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// [ThemeController]를 화면 어디서나 찾을 수 있게 합니다.
///
/// 상태 관리 패키지를 새로 넣지 않은 이유는 공유할 값이 이것 하나뿐이기
/// 때문입니다. 필요가 늘어나면 그때 도입하는 편이 낫습니다.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 가장 가까운 컨트롤러. 설정 화면에서 씁니다.
  ///
  /// 없으면 null입니다 — 테스트에서 화면만 따로 띄우는 경우가 있어
  /// 던지지 않습니다.
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
