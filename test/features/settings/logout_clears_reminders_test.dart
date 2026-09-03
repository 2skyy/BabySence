import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 로그아웃할 때 이 폰에 걸어 둔 알림을 지웁니다.
///
/// 수유·예방접종 알림은 **기기 안에** 예약되므로 계정을 바꿔도 남습니다.
/// 예약 문구에는 아이 이름이 들어갑니다
/// (`vaccination_reminder_service.dart`의 `$name 예방접종 예정일이 다가와요`).
/// 지우지 않으면 이 폰으로 다음에 로그인한 사람에게 **앞사람 아이 이름이
/// 뜹니다.** FCM 토큰을 지우는 것과 같은 이유입니다.
void main() {
  final source =
      File('lib/features/settings/settings_page.dart').readAsStringSync();

  test('로그아웃이 FCM 토큰을 지운다', () {
    expect(source, contains('PushService.clearToken()'));
  });

  test('로그아웃이 예약된 수유·예방접종 알림도 지운다', () {
    final i = source.indexOf('_handleLogout');
    expect(i, isNot(-1));
    final block = source.substring(i, i + 1400);
    expect(block, contains('FeedingReminderService.cancel()'),
        reason: '수유 알림 예약이 남아 다음 사용자에게 울립니다');
    expect(block, contains('VaccinationReminderService.cancelAll()'),
        reason: '접종 알림 예약이 남아 앞사람 아이 이름이 뜹니다');
  });
}
