import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// postgrest의 `order()` 기본값은 **내림차순**입니다.
///
///   `PostgrestTransformBuilder<T> order(String column, {bool ascending = false})`
///
/// 그래서 `.order('created_at')`만 쓰면 '가장 먼저'가 아니라 '가장 나중'이
/// 됩니다. `BabyService.loadCurrent()`가 정확히 이걸 놓쳤습니다 — 주석은
/// "가장 먼저 등록한 아이를 씁니다"라고 적어 두고 코드는 반대로 돌았습니다.
///
/// 그 결과가 **함께 키우기가 조용히 무효가 되는 것**이었습니다. 자기 아이를
/// 등록해 둔 사람이 초대를 받으면, 코드를 수락해도 계속 자기 아이만 보입니다.
/// 오류도 빈 화면도 아니라 알아채기 어렵습니다.
void main() {
  test('order()에 방향을 반드시 적는다', () {
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('.order(')) continue;

        // 같은 줄이나 다음 두 줄 안에 방향이 적혀 있으면 됩니다
        // (긴 호출은 줄바꿈되기 때문입니다).
        final window = lines.skip(i).take(3).join(' ');
        if (window.contains('ascending:')) continue;

        offenders.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: '기본값이 내림차순입니다. 의도한 방향을 적어 주세요:\n'
            '${offenders.join('\n')}');
  });

  test('아이는 가장 먼저 등록한 것을 고른다', () {
    // 함께 키우기가 여기에 달려 있습니다.
    final source = File('lib/core/services/baby_service.dart').readAsStringSync();
    expect(source.contains("order('created_at', ascending: true)"), isTrue);
  });
}
