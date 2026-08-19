import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 알림 셋(수유·예방접종·알림 시험)이 **함께 쓰는** 초기화 설정.
///
/// 셋이 각자 적어 두었더니 `macOS` 항목이 세 곳 모두에서 빠졌습니다. 이
/// 플러그인은 macOS에서 그 항목이 없으면 초기화 단계에서 예외를 던지므로
/// ("macOS settings must be set when targeting macOS platform") 데스크톱에서는
/// 알림이 통째로 죽어 있었고, 세 곳을 각각 고쳐야 했습니다. 한 곳에서 만들면
/// 플랫폼이 늘어도 한 번만 고치고, 새 알림이 생겨도 빠뜨릴 자리가 없습니다.
///
/// [requestPermissions]는 **Darwin(iOS·macOS)에서 권한을 물을지**입니다.
/// 예약하는 쪽은 묻지 않습니다 — 예약은 앱이 알아서 거는 일이라 그때 권한
/// 창이 뜨면 뜬금없습니다. 모바일은 앱 시작 때 permission_handler가 한 번에
/// 받지만 macOS에는 그 경로가 없어, 사용자가 직접 누르는 알림 시험에서만
/// 묻습니다. 거기서 묻지 않으면 예약만 되고 아무것도 뜨지 않습니다.
InitializationSettings notificationInitSettings({
  bool requestPermissions = false,
}) {
  final darwin = DarwinInitializationSettings(
    requestAlertPermission: requestPermissions,
    requestBadgePermission: requestPermissions,
    requestSoundPermission: requestPermissions,
  );

  return InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: darwin,
    macOS: darwin,
  );
}

/// 알림 상세의 Darwin 쪽. 채널 설정이 없는 두 플랫폼은 같은 값을 씁니다.
///
/// [notificationInitSettings]와 같은 이유로 한 곳에 둡니다 — 여기서도
/// `macOS`가 빠지면 그 플랫폼에서만 조용히 다르게 동작합니다.
const DarwinNotificationDetails darwinNotificationDetails =
    DarwinNotificationDetails();
