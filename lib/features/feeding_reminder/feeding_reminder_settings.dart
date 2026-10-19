import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 수유 알림 설정.
///
/// 기기에만 둡니다. 알림은 이 기기가 울리는 것이고, 함께 키우는 두 사람이
/// 서로 다른 간격을 쓸 수도 있어 서버에 올리지 않습니다.
///
/// 간격이 null이면 **아직 정하지 않은 것**입니다. 이때는 다음 시각을
/// 계산하지 않습니다 — 앱이 임의의 값을 채워 넣으면 그 숫자가 근거처럼
/// 읽힙니다.
@immutable
class FeedingReminderSettings {
  final Duration? interval;

  /// 알림을 울릴지. 간격만 정하고 알림은 끄는 경우가 있어 따로 둡니다
  /// (홈 화면에서 다음 시각만 보고 싶을 때).
  final bool notify;

  const FeedingReminderSettings({this.interval, this.notify = true});

  static const _intervalKey = 'feeding_reminder_interval_minutes';
  static const _notifyKey = 'feeding_reminder_notify';

  static const none = FeedingReminderSettings();

  bool get isConfigured => interval != null;

  static Future<FeedingReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_intervalKey);
    return FeedingReminderSettings(
      interval: minutes == null ? null : Duration(minutes: minutes),
      notify: prefs.getBool(_notifyKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final gap = interval;
    if (gap == null) {
      await prefs.remove(_intervalKey);
    } else {
      await prefs.setInt(_intervalKey, gap.inMinutes);
    }
    await prefs.setBool(_notifyKey, notify);
  }

  FeedingReminderSettings copyWith({Duration? interval, bool? notify}) =>
      FeedingReminderSettings(
        interval: interval ?? this.interval,
        notify: notify ?? this.notify,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedingReminderSettings &&
      other.interval == interval &&
      other.notify == notify;

  @override
  int get hashCode => Object.hash(interval, notify);
}
