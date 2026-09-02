import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 섭씨 기호가 `℃`(U+2103)와 `°C`(도 기호 + C) 두 가지로 갈려 있었습니다.
/// 체온 화면 한 곳에서 둘이 함께 보였습니다.
///
/// 인용문은 예외입니다 — 원문을 그대로 옮긴 주석은 바꾸면 인용이 아니게 됩니다.
void main() {
  test('보호자에게 보이는 섭씨는 ℃ 하나로 쓴다', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('°C')) continue;
        // 주석 안의 원문 인용은 그대로 둡니다.
        if (line.trimLeft().startsWith('//')) continue;
        offenders.add('${f.path}:${i + 1}  ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: '°C 대신 ℃를 쓰세요:\n${offenders.join('\n')}');
  });
}
