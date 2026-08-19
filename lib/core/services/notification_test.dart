import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'notification_setup.dart';

/// 알림 시험의 결과.
///
/// **"예약했다"와 "떴다"는 다릅니다.** 예약은 성공해도 절전 정책이나 방해 금지
/// 모드가 막으면 뜨지 않습니다. 그래서 예약 성공만으로 "된다"고 말하지 않고,
/// 확인한 것과 확인하지 못한 것을 나눠 돌려줍니다.
@immutable
class NotificationTestResult {
  /// 이 앱의 알림이 켜져 있는지. 안드로이드에만 있어 그 밖에서는 null입니다.
  final bool? enabled;

  /// 예약을 걸었는지.
  final bool scheduled;

  /// 실패했다면 그 까닭.
  final String? error;

  const NotificationTestResult({
    required this.enabled,
    required this.scheduled,
    this.error,
  });
}

/// 알림이 실제로 뜨는지 확인하기 위한 시험용 알림.
///
/// 수유·예방접종 알림과 **같은 방식**으로 겁니다(로컬 예약,
/// `inexactAllowWhileIdle`). 그래야 이 시험이 통과하면 그 둘도 뜬다고 말할 수
/// 있습니다. 다른 점은 시각뿐입니다 — 몇 시간 뒤가 아니라 [delay] 뒤입니다.
class NotificationTest {
  /// 수유(2001)·접종(3001~3030)·배경 서비스(888)와 겹치지 않는 자리.
  static const int _id = 9001;

  static const String _channelId = 'babysense_test';
  static const String _channelName = '알림 시험';
  static const String _channelDescription = '알림이 뜨는지 확인하는 시험용입니다.';

  /// 기다리는 시간. 설정 화면을 벗어나 알림창을 볼 만한 여유입니다.
  static const Duration delay = Duration(seconds: 10);

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<NotificationTestResult> fire() async {
    if (kIsWeb) {
      return const NotificationTestResult(
        enabled: null,
        scheduled: false,
        error: '웹에서는 알림을 쓸 수 없습니다.',
      );
    }

    try {
      tz_data.initializeTimeZones();

      await _plugin.initialize(
        settings: notificationInitSettings(requestPermissions: true),
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      // 권한이 꺼져 있으면 예약은 되고 알림만 안 뜹니다. 그러면 "예약했는데
      // 안 뜬다"가 되어 원인을 알 수 없으므로 미리 물어봅니다.
      final enabled = await android?.areNotificationsEnabled();

      await _plugin.cancel(id: _id);
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().toUtc().add(delay),
          tz.UTC,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '알림이 잘 뜹니다',
        body: '수유·예방접종 알림도 같은 방식으로 뜹니다.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: darwinNotificationDetails,
          macOS: darwinNotificationDetails,
        ),
      );

      return NotificationTestResult(enabled: enabled, scheduled: true);
    } catch (e) {
      return NotificationTestResult(
        enabled: null,
        scheduled: false,
        error: '$e',
      );
    }
  }
}
