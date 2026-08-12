import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 두 표에 나눠 넣는 저장이 셋 있습니다. 어느 것이든 2단계가 실패했을 때
/// **통째로 실패했다고 말하면** 사용자가 다시 눌러 1단계가 중복됩니다.
///
///   체온   : temperature_records → temperature_symptoms
///   온보딩 : babies             → growth_records
///   소음   : sleep_records      → sleep_noise_logs   (이미 처리됨)
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('체온 — 증상 실패를 예외로 던지지 않는다', () {
    final service =
        read('lib/features/detail/temperature_record_service.dart');
    expect(service.contains('static Future<bool> save('), isTrue,
        reason: '증상 저장 성공 여부를 결과로 알려야 합니다');

    final page = read('lib/features/detail/temperature_record_page.dart');
    expect(page.contains('체온은 저장했지만 동반 증상은 저장하지 못했습니다'), isTrue,
        reason: '체온은 들어갔다는 사실을 말해야 다시 누르지 않습니다');
  });

  test('온보딩 — 재시도해도 아이를 두 번 만들지 않는다', () {
    // loadCurrent()는 늘 첫 행을 고르므로, 두 번째 아이는 어느 화면에도
    // 나오지 않고 지울 수단도 없습니다.
    final page = read('lib/features/onboarding/child_info_page.dart');
    expect(page.contains('_created ??='), isTrue);
  });

  group('저장 순간에 아이를 다시 고르지 않는다', () {
    // 화면을 열 때 조회가 실패했다면 그 사이 함께 보기가 끊기는 등으로
    // **다른 아이가 뽑힐 수 있습니다.** 보고 있던 아이가 아닌 곳에 기록이
    // 저장되고, 사용자에게는 아무 표시도 없습니다.
    const pages = [
      'lib/features/detail/temperature_record_page.dart',
      'lib/features/detail/sleep_record_page.dart',
      'lib/features/detail/feeding_record_page.dart',
      'lib/features/detail/diaper_record_page.dart',
      'lib/features/detail/care/care_record_page.dart',
    ];

    for (final path in pages) {
      test(path.split('/').last, () {
        expect(read(path).contains('_baby ?? await BabyService.loadCurrent()'),
            isFalse,
            reason: '화면을 열 때 잡은 아이에만 저장하세요');
      });
    }
  });
}
