import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'feeding_schedule.dart';

/// 다음 수유 시각에 한 번 울리는 알림.
///
/// 되풀이가 아니라 **한 번짜리**입니다. 수유를 기록할 때마다 다음 시각을 다시
/// 잡습니다. 되풀이로 두면 기록을 남겨도 예전 리듬으로 계속 울립니다.
class FeedingReminderService {
  /// 예약을 덮어쓰기 위한 고정 id. 매번 새 id를 쓰면 예전 예약이 남아
  /// 여러 번 울립니다.
  static const int _notificationId = 2001;

  static const String _channelId = 'babysense_feeding';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  /// 알림 채널과 시간대 데이터를 준비합니다. 여러 번 불러도 한 번만 합니다.
  static Future<void> _prepare() async {
    if (_ready) return;

    tz_data.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // 권한은 앱 시작 때 permission_handler로 한 번에 받습니다.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        '수유 알림',
        description: '정한 수유 간격이 되면 알려줍니다.',
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  /// [schedule]에 맞춰 알림을 다시 잡습니다.
  ///
  /// 알림을 끄거나, 간격을 정하지 않았거나, 예정 시각이 이미 지났으면
  /// 예약을 지우기만 합니다 — 지난 시각으로 예약하면 즉시 울립니다.
  static Future<void> reschedule(
    FeedingSchedule schedule, {
    required bool notify,
    DateTime? now,
  }) async {
    // 테스트와 웹에서는 플러그인이 없습니다. 알림이 없다고 기록이 막히면 안 됩니다.
    if (kIsWeb) return;

    try {
      await _prepare();
      await _plugin.cancel(id: _notificationId);

      final at = schedule.nextAt;
      if (!notify || at == null) return;
      if (!at.isAfter(now ?? DateTime.now())) return;

      await _plugin.zonedSchedule(
        id: _notificationId,
        // 되풀이가 아닌 한 번짜리라 '어느 시간대로 적었는지'는 상관없고
        // **같은 순간**이기만 하면 됩니다. 기기 시간대 이름을 따로 알아낼
        // 필요가 없도록 UTC로 적습니다.
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        // 정확한 알람(exact)은 안드로이드 12+에서 별도 권한을 요구합니다.
        // 수유 알림은 몇 분 늦어도 되는 종류라 권한 벽을 세우지 않습니다.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '수유할 시간이에요',
        body: '${formatClock(at)}로 정하신 시간이 되었어요.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '수유 알림',
            channelDescription: '정한 수유 간격이 되면 알려줍니다.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      // 알림을 잡지 못해도 기록과 화면은 그대로 동작해야 합니다.
      debugPrint('수유 알림을 예약하지 못했습니다: $e');
    }
  }

  /// 예약을 지웁니다.
  static Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _prepare();
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('수유 알림을 지우지 못했습니다: $e');
    }
  }
}
