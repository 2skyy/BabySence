import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 200인데 본문이 Map이 아닌 응답을 오류로 말합니다.
///
/// `response.data as Map`은 프록시가 끼워 넣은 HTML 안내문이나 빈 본문에서
/// TypeError를 던집니다. 그 예외는 `SkinException`도 `SkinUnreadable`도
/// 아니라 화면의 catch 둘을 모두 지나칩니다. `finally`가 spinner는 끄지만
/// 문구는 **"사진을 확인하는 중입니다…"에 그대로 남습니다** — 오류도
/// 결과도 없이 확인 중이라고 말하는 화면이 됩니다.
///
/// 이 앱은 확인하지 못한 것이 안심으로 읽히지 않게 하려고 판독 불가와
/// 통신 실패 양쪽에 한 줄씩 덧붙여 두었습니다. 여기만 그 그물 밖입니다.
void main() {
  final source =
      File('lib/features/detail/skin/skin_service.dart').readAsStringSync();

  test('본문이 Map이 아니면 SkinException으로 말한다', () {
    expect(source, isNot(contains('response.data as Map;')),
        reason: '맨 캐스트는 화면의 catch 둘을 모두 지나칩니다');
    expect(source, contains('is! Map'),
        reason: '본문 모양을 확인하고 SkinException으로 바꿔야 합니다');
  });
}
