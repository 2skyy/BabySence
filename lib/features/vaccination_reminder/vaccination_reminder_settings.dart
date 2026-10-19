import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 예방접종 알림 설정.
///
/// 수유 알림과 같은 이유로 **기기에만 둡니다** — 알림은 이 기기가 울리는
/// 것이고, 함께 키우는 두 사람이 서로 다른 시점을 쓸 수 있습니다.
///
/// 수유 알림과 달리 **기본값이 있습니다.** 접종 예정일은 앱이 정한 값이
/// 아니라 질병관리청 표준 일정에서 나온 날짜라, 며칠 전에 알릴지는 앱이
/// 골라도 근거를 왜곡하지 않습니다.
@immutable
class VaccinationReminderSettings {
  /// 알림을 울릴지.
  final bool notify;

  /// 예정일 며칠 전에 알릴지. 0이면 당일입니다.
  final int daysBefore;

  const VaccinationReminderSettings({
    this.notify = false,
    this.daysBefore = defaultDaysBefore,
  });

  /// 처음에는 꺼 둡니다. 켠 적 없는 알림이 갑자기 울리면 안 됩니다.
  static const bool defaultNotify = false;

  /// 병원 예약을 잡을 만한 여유입니다. 의학적 근거가 있는 값이 아니라
  /// **편의를 위한 기본값**이고, 보호자가 바꾸는 것을 전제로 합니다.
  static const int defaultDaysBefore = 3;

  /// 고를 수 있는 값. 당일 · 1일 · 3일 · 7일 전.
  static const List<int> selectableDaysBefore = [0, 1, 3, 7];

  static const _notifyKey = 'vaccination_reminder_notify';
  static const _daysBeforeKey = 'vaccination_reminder_days_before';

  static Future<VaccinationReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return VaccinationReminderSettings(
      notify: prefs.getBool(_notifyKey) ?? defaultNotify,
      daysBefore: prefs.getInt(_daysBeforeKey) ?? defaultDaysBefore,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyKey, notify);
    await prefs.setInt(_daysBeforeKey, daysBefore);
  }

  VaccinationReminderSettings copyWith({bool? notify, int? daysBefore}) =>
      VaccinationReminderSettings(
        notify: notify ?? this.notify,
        daysBefore: daysBefore ?? this.daysBefore,
      );

  @override
  bool operator ==(Object other) =>
      other is VaccinationReminderSettings &&
      other.notify == notify &&
      other.daysBefore == daysBefore;

  @override
  int get hashCode => Object.hash(notify, daysBefore);
}

/// '3일 전', '당일'처럼 읽습니다.
String formatDaysBefore(int days) => days == 0 ? '당일' : '$days일 전';
