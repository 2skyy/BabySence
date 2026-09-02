import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 사진 판독이 실패하는 길은 둘입니다.
///
///   1. 판독 불가 — 사진에서 피부를 못 봄
///   2. 통신·서버 실패 — 503, 시간 초과 등
///
/// 1번에는 "확인하지 못했다는 것은 괜찮다는 뜻이 아닙니다"가 붙어 있는데
/// 2번에는 없었습니다. **보호자에게는 둘 다 결과를 못 받은 것**이고,
/// 새벽에 서버가 죽어 오류만 뜨면 그것도 안심으로 읽힙니다.
void main() {
  final source =
      File('lib/features/detail/skin_analysis_page.dart').readAsStringSync();

  test('판독 불가에 안심 방지 문구가 있다', () {
    expect(source, contains('SkinUnreadable'));
    expect(source, contains('괜찮다는 뜻이 아닙니다'));
  });

  test('통신 실패에도 같은 문구가 붙는다', () {
    // SkinException(통신·서버 실패) 분기를 잘라내 그 안을 봅니다.
    final i = source.indexOf('on SkinException');
    expect(i, isNot(-1), reason: 'SkinException 분기를 찾지 못했습니다');
    final block = source.substring(i, i + 600);
    expect(block, contains('괜찮다는 뜻이 아닙니다'),
        reason: '서버가 죽어 결과를 못 받은 것도 안심으로 읽힙니다. '
            '판독 불가와 같은 한 줄이 필요합니다');
  });
}
