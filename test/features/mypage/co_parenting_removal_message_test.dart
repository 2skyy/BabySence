import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 내보내기 결과를 목록으로 확인할 때, **목록을 못 읽은 경우를 가려냅니다.**
///
/// 삭제는 정책이 막으면 0행으로 조용히 끝나므로 목록을 다시 읽어 확인합니다.
/// 그런데 그 재조회가 실패하면 `_members`는 **낡은 값 그대로** 남습니다 —
/// 방금 내보낸 사람이 아직 있는 것으로 보이고, 화면은 "권한이 없어 처리하지
/// 못했습니다"라고 말합니다.
///
/// 실제로는 내보내기가 성공했고 원인은 통신입니다. 게다가 `_load()`가 이미
/// 자기 오류 문구를 띄운 뒤라, 보호자는 서로 다른 말 둘을 연달아 봅니다.
/// 함께 키우기는 상대가 아이 기록을 계속 볼 수 있는지가 걸린 화면이라
/// 성공을 실패로 말하면 같은 일을 한 번 더 하게 됩니다.
void main() {
  final source =
      File('lib/features/mypage/co_parenting_page.dart').readAsStringSync();

  test('목록 재조회 실패를 권한 없음으로 말하지 않는다', () {
    final i = source.indexOf('final stillThere');
    expect(i, isNot(-1), reason: '목록으로 확인하는 자리가 사라졌습니다');
    final block = source.substring(i - 400, i + 400);
    expect(block, contains('_loadFailed'),
        reason: '재조회가 실패했는지 보지 않으면 낡은 목록을 근거로 말합니다');
  });
}
