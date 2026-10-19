import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 소음의 `consult`는 보호자에게 '개선 권장'으로 보여야 합니다.
/// `level.label`을 그대로 쓰면 '상담 권장'이 되어 **방이 시끄럽다는 이유로
/// 병원에 가라는 말**로 읽힙니다. 그래서 `Assessment.levelLabel`이 있습니다.
///
/// 이 검사는 그 우회로가 다시 생기는 것을 막습니다. 과거에 쓰이지 않는
/// 함수 하나가 옛 표기를 그대로 들고 남아 있었습니다.
void main() {
  test('보호자에게 보이는 판정 이름은 levelLabel을 지나간다', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // 정의한 곳 자신은 예외입니다.
      if (f.path.endsWith('assessment.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('.level.label')) {
          offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'level.label 대신 levelLabel을 쓰세요 '
            '(소음은 "상담 권장"이 아니라 "개선 권장"입니다):\n'
            '${offenders.join('\n')}');
  });
}
