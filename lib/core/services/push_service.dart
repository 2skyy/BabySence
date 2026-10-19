import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_time.dart';
import 'notification_setup.dart';

/// 서버가 보내는 알림(FCM)을 받습니다.
///
/// ## 로컬 알림과 무엇이 다른가
///
/// 수유·예방접종 알림은 **시각이 이미 정해져 있어** 기기가 스스로 울립니다.
/// 서버도 인터넷도 필요 없습니다(`feeding_reminder_service.dart`,
/// `vaccination_reminder_service.dart`).
///
/// 이쪽은 **기기가 미리 알 수 없는 일**을 위한 것입니다 — 내 글에 달린 댓글,
/// 함께 키우는 보호자가 남긴 기록, 운영자 공지. 언제 생길지 모르므로 서버가
/// 깨워 주어야 합니다.
///
/// ## 이 파일이 하는 일과 하지 않는 일
///
/// **합니다**: 이 기기의 주소(FCM 토큰)를 받아 `device_tokens`에 저장하고,
/// 도착한 알림을 화면에 띄웁니다.
///
/// **하지 않습니다**: 보내는 일. 그건 서버(Supabase Edge Function 등)의
/// 몫이고, 저장소에는 아직 없습니다. 설정 방법은
/// `docs/firebase-push-setup.md`에 적어 두었습니다.
///
/// ## 설정 파일이 없으면 조용히 꺼집니다
///
/// `google-services.json`이 없으면 `Firebase.initializeApp()`이 실패하고,
/// 그 상태에서 이 서비스를 부르면 예외가 납니다. 앱의 나머지가 그것 때문에
/// 멈추면 안 되므로 [isAvailable]로 먼저 확인하고 넘어갑니다.
class PushService {
  /// 앞에 온 알림을 띄우는 채널.
  ///
  /// **앱이 열려 있을 때는 FCM이 알림을 그리지 않습니다.** 데이터만 앱에
  /// 넘어오므로, 그때는 로컬 알림으로 우리가 직접 띄웁니다. 앱이 꺼져 있거나
  /// 뒤에 있을 때는 안드로이드가 알아서 그립니다.
  static const String channelId = 'babysense_push';
  static const String _channelName = '알림';
  static const String _channelDescription = '댓글·공지처럼 서버가 보내는 알림입니다.';

  /// 수유(2001)·접종(3001~)·시험(9001)·배경 서비스(888)와 겹치지 않는 자리.
  static const int _idBase = 5000;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _started = false;

  /// 같은 토큰을 여러 번 쓰지 않기 위한 것. 앱이 사는 동안만 기억합니다.
  static String? _savedToken;

  /// Firebase가 준비되어 있는지.
  ///
  /// 설정 파일이 없으면 `Firebase.initializeApp()`이 실패해 앱이 하나도
  /// 없습니다. 그때 [FirebaseMessaging.instance]를 만지면 예외가 납니다.
  static bool get isAvailable {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 알림을 받을 준비를 합니다. 앱이 사는 동안 한 번만 부릅니다.
  ///
  /// 토큰 저장은 **로그인한 뒤에만** 됩니다(`device_tokens`가 사용자에
  /// 묶여 있고 RLS가 남의 행을 막습니다). 로그인 전에 불러도 흐름은 걸어
  /// 두므로, 나중에 [syncToken]을 부르면 그때 저장됩니다.
  static Future<void> start() async {
    if (_started || !isAvailable) return;
    _started = true;

    try {
      await _prepareChannel();

      // 앱이 앞에 있을 때 도착한 것. FCM은 이때 알림을 그리지 않습니다.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // 서버가 새 토큰을 발급하면(앱 재설치, 캐시 초기화 등) 흘러 들어옵니다.
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _savedToken = null;
        _saveToken(token);
      });

      await syncToken();
    } catch (e) {
      debugPrint('푸시 알림을 준비하지 못했습니다: $e');
    }
  }

  /// 지금 토큰을 서버에 맞춰 둡니다. 로그인 직후에도 부릅니다.
  static Future<void> syncToken() async {
    if (!isAvailable) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _saveToken(token);
    } catch (e) {
      debugPrint('푸시 토큰을 읽지 못했습니다: $e');
    }
  }

  /// 로그아웃할 때 이 기기의 토큰을 지웁니다.
  ///
  /// **지우지 않으면 다음 사람에게 앞사람의 알림이 갑니다.** 한 폰을 두
  /// 계정이 쓰는 일이 드물지 않습니다.
  static Future<void> clearToken() async {
    _savedToken = null;
    if (!isAvailable) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('fcm_token', token);
    } catch (e) {
      // 로그아웃 자체를 막지 않습니다. 남은 행은 서버가 보낼 때
      // 실패 응답을 받아 정리합니다.
      debugPrint('푸시 토큰을 지우지 못했습니다: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    if (_savedToken == token) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': toDbTime(DateTime.now()),
        },
        // 토큰이 UNIQUE라, 계정을 바꿔 로그인하면 같은 행의 주인만 바뀝니다.
        onConflict: 'fcm_token',
      );
      _savedToken = token;
    } catch (e) {
      debugPrint('푸시 토큰을 저장하지 못했습니다: $e');
    }
  }

  static Future<void> _prepareChannel() async {
    await _plugin.initialize(settings: notificationInitSettings());

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  /// 앱이 앞에 있을 때 도착한 알림을 직접 띄웁니다.
  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // 제목도 내용도 없으면 빈 알림이 뜹니다. 그럴 바엔 띄우지 않습니다.
    final title = notification.title;
    final body = notification.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    try {
      await _plugin.show(
        id: _idBase + (message.messageId?.hashCode ?? 0).abs() % 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: darwinNotificationDetails,
          macOS: darwinNotificationDetails,
        ),
      );
    } catch (e) {
      debugPrint('도착한 알림을 띄우지 못했습니다: $e');
    }
  }
}
