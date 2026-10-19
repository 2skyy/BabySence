import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_project/core/services/notification_setup.dart';

/// 알림 초기화 설정은 **한 곳에서만** 만듭니다.
///
/// 수유·예방접종·알림 시험 셋이 각자 적어 두었더니 `macOS` 항목이 세 곳
/// 모두에서 빠졌습니다. 이 플러그인은 macOS에서 그 항목이 없으면 초기화
/// 단계에서 예외를 던지므로, 데스크톱에서는 알림이 통째로 죽어 있었고
/// 세 곳을 각각 고쳐야 했습니다.
void main() {
  test('세 플랫폼이 모두 채워진다', () {
    final settings = notificationInitSettings();

    expect(settings.android, isNotNull);
    expect(settings.iOS, isNotNull);
    expect(settings.macOS, isNotNull,
        reason: 'macOS가 비면 그 플랫폼에서 초기화가 예외를 던집니다');
  });

  test('예약하는 쪽은 권한을 묻지 않는다', () {
    // 예약은 앱이 알아서 거는 일이라 그때 권한 창이 뜨면 뜬금없습니다.
    final darwin = notificationInitSettings().macOS as DarwinInitializationSettings;

    expect(darwin.requestAlertPermission, isFalse);
    expect(darwin.requestSoundPermission, isFalse);
    expect(darwin.requestBadgePermission, isFalse);
  });

  test('알림 시험은 권한을 묻는다', () {
    // macOS에는 permission_handler로 한 번에 받는 경로가 없어, 여기서
    // 묻지 않으면 예약만 되고 아무것도 뜨지 않습니다.
    final darwin = notificationInitSettings(requestPermissions: true).macOS
        as DarwinInitializationSettings;

    expect(darwin.requestAlertPermission, isTrue);
    expect(darwin.requestSoundPermission, isTrue);
    expect(darwin.requestBadgePermission, isTrue);
  });

  test('iOS와 macOS가 같은 값을 쓴다', () {
    // 한쪽만 고치면 그 플랫폼에서만 조용히 다르게 동작합니다.
    final settings = notificationInitSettings(requestPermissions: true);
    expect(identical(settings.iOS, settings.macOS), isTrue);
  });

  test('초기화 설정을 다른 곳에서 만들지 않는다', () {
    // 이 검사가 없으면 네 번째 알림이 생길 때 같은 일이 되풀이됩니다.
    // 화면 코드에는 위젯 테스트를 붙이기 어려운 자리가 많아 글자로 막습니다.
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('notification_setup.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('InitializationSettings(')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty,
        reason: 'notificationInitSettings()를 쓰세요. 직접 적으면 플랫폼 하나를 '
            '빠뜨려도 그 플랫폼에서만 조용히 죽습니다:\n${offenders.join('\n')}');
  });
}
