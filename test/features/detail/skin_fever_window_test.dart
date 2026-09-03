import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 발진 사진과 함께 보내는 발열 여부가 조회 한도에 잘리지 않습니다.
///
/// `_recentFever`는 12시간 창을 `since`로 주면서 기본 `limit: 20`을 그대로
/// 썼습니다. 조회는 최신순이라 창 안에 20건이 넘으면 **가장 오래된 쪽부터**
/// 빠집니다 — 열이 나서 자주 잰 아이일수록 그렇고, 해열제로 내려가기 전의
/// 고열이 바로 그 자리에 있습니다. 그러면 `any(>= 38)`이 false가 되어
/// 사진과 함께 `'no'`가 나갑니다. 재보지 않았다는 `'unknown'`과 달리 이건
/// **열이 없다고 잘못 말하는 것**이고, 발진과 발열이 같이 있는 것은 카메라가
/// 담지 못하는 가장 값진 신호입니다.
///
/// `temperature_record_service.dart`의 `loadRecent` 주석이 바로 이 함정을
/// 경고하고 있습니다: "기간을 말하는 화면은 반드시 since를 써야 합니다".
void main() {
  final source =
      File('lib/features/detail/skin_analysis_page.dart').readAsStringSync();

  String feverBody() {
    final i = source.indexOf('_recentFever(String babyId)');
    expect(i, isNot(-1));
    return source.substring(i, source.indexOf('Future<void> _analyze', i));
  }

  test('12시간 창 전체를 읽는다 — 기본 한도에 기대지 않는다', () {
    expect(feverBody(), contains('limit:'),
        reason: '기본 limit 20이면 창 앞쪽의 고열이 빠져 no가 됩니다');
  });

  test('조회 실패를 열 없음으로 접지 않는다', () {
    expect(feverBody(), contains("return 'unknown'"));
  });
}
