import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../detail/vaccination_service.dart';
import 'vaccination_reminder_settings.dart';

/// 다가오는 예방접종을 미리 알려줍니다.
///
/// **판정하지 않습니다.** "맞아야 한다"가 아니라 "표준 일정상 예정일이
/// 다가온다"만 말합니다. 접종 가능 여부는 진찰로 가리는 것이라 앱이 계산할
/// 수 없습니다(`vaccination_readiness.dart`에 근거가 정리되어 있습니다).
///
/// 수유 알림과 달리 **여러 개를 동시에 걸어 둡니다.** 접종은 몇 달 뒤 것까지
/// 날짜가 정해져 있어, 다음 하나만 걸면 앱을 안 여는 동안 그다음을 놓칩니다.
class VaccinationReminderService {
  /// 알림 id를 나누는 기준.
  ///
  /// 수유 알림이 2001을 쓰므로 겹치지 않는 자리를 잡았습니다. `vaccines.id`는
  /// smallint 1~30이라 3001~3030에 들어갑니다. **백신마다 고정 id**여야
  /// 다시 걸 때 예전 예약이 남지 않습니다.
  static const int _idBase = 3000;

  /// 한 번에 걸어 둘 개수의 상한.
  ///
  /// 안드로이드는 앱당 예약 알람 수에 한계가 있고, 몇 년 뒤 것까지 걸어 둘
  /// 이유도 없습니다. 표준 일정은 시기별로 묶여 있어 이 정도면 다음 방문
  /// 두어 번을 덮습니다.
  static const int _maxScheduled = 8;

  /// 알림이 울릴 시각(24시간제). 새벽에 울리면 안 되고, 병원에 전화할 수
  /// 있는 시간대여야 합니다.
  static const int _hour = 9;

  static const String _channelId = 'babysense_vaccination';
  static const String _channelName = '예방접종 알림';
  static const String _channelDescription = '접종 예정일이 다가오면 알려줍니다.';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

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
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  /// 알림을 울릴 시각. 예정일에서 [daysBefore]만큼 당긴 날 오전 9시입니다.
  ///
  /// [scheduledOn]은 날짜만 있는 값(자정)이라 그대로 쓰면 한밤중에 울립니다.
  static DateTime notifyAtFor(DateTime scheduledOn, int daysBefore) {
    final day = DateTime(scheduledOn.year, scheduledOn.month, scheduledOn.day)
        .subtract(Duration(days: daysBefore));
    return DateTime(day.year, day.month, day.day, _hour);
  }

  /// [schedule]에 맞춰 알림을 **전부 다시 잡습니다.**
  ///
  /// 접종을 마치거나 날짜를 고치면 예전 예약이 남으면 안 되므로, 늘 모두
  /// 지우고 새로 겁니다. 이미 맞은 것과 시각이 지난 것은 건너뜁니다 —
  /// 지난 시각으로 예약하면 그 자리에서 울립니다.
  static Future<void> reschedule(
    List<VaccinationStatus> schedule, {
    required VaccinationReminderSettings settings,
    DateTime? now,
  }) async {
    // 테스트와 웹에는 플러그인이 없습니다. 알림이 없다고 화면이 막히면 안 됩니다.
    if (kIsWeb) return;

    try {
      await _prepare();
      await _cancelAll();
      if (!settings.notify) return;

      final at = now ?? DateTime.now();

      final upcoming = [
        for (final status in schedule)
          if (!status.isDone) status,
      ]..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));

      var scheduled = 0;
      for (final status in upcoming) {
        if (scheduled >= _maxScheduled) break;

        final notifyAt = notifyAtFor(status.scheduledOn, settings.daysBefore);
        if (!notifyAt.isAfter(at)) continue;

        await _scheduleOne(status, notifyAt, settings.daysBefore);
        scheduled++;
      }
    } catch (e) {
      // 알림을 잡지 못해도 접종 일정 화면은 그대로 동작해야 합니다.
      debugPrint('예방접종 알림을 예약하지 못했습니다: $e');
    }
  }

  static Future<void> _scheduleOne(
    VaccinationStatus status,
    DateTime notifyAt,
    int daysBefore,
  ) async {
    final vaccine = status.vaccine;
    final when = daysBefore == 0
        ? '오늘'
        : '${_formatDate(status.scheduledOn)}($daysBefore일 뒤)';

    await _plugin.zonedSchedule(
      id: _idBase + vaccine.id,
      // 되풀이가 아닌 한 번짜리라 '어느 시간대로 적었는지'는 상관없고
      // **같은 순간**이기만 하면 됩니다. 수유 알림과 같은 방식입니다.
      scheduledDate: tz.TZDateTime.from(notifyAt.toUtc(), tz.UTC),
      // 정확한 알람(exact)은 안드로이드 12+에서 별도 권한을 요구합니다.
      // 며칠 전 알림이라 몇 분 늦어도 되는 종류입니다.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: '예방접종 예정일이 다가와요',
      // **표준 일정을 옮겨 적기만 합니다.** 맞아야 한다고 말하지 않습니다.
      body: '${vaccine.name} 접종 예정일이 $when이에요.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// 걸어 둔 예약을 모두 지웁니다.
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _prepare();
      await _cancelAll();
    } catch (e) {
      debugPrint('예방접종 알림을 지우지 못했습니다: $e');
    }
  }

  /// **`cancelAll()`(플러그인 것)을 쓰지 않습니다.** 그것은 수유 알림과
  /// 배경 서비스 알림까지 함께 지웁니다.
  static Future<void> _cancelAll() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id > _idBase && request.id <= _idBase + 999) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  static String _formatDate(DateTime date) => '${date.month}월 ${date.day}일';
}
