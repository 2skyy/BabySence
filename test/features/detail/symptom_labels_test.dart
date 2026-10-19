import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/temperature_record_service.dart';

/// 화면이 증상 이름을 손으로 다시 적으면, enum과 한 글자만 어긋나도
/// `Symptom.fromLabel`이 null을 돌려주고 `whereType<Symptom>()`이
/// **조용히 버립니다.** 보호자는 체크했는데 저장이 안 됩니다.
///
/// 화면은 이제 `Symptom.values`에서 이름을 가져오므로 어긋날 수 없습니다.
/// 이 테스트는 그 왕복이 실제로 성립하는지 봅니다.
void main() {
  test('모든 증상 이름이 enum으로 되돌아온다', () {
    expect(Symptom.values, isNotEmpty);
    for (final s in Symptom.values) {
      expect(Symptom.fromLabel(s.label), s,
          reason: "'\${s.label}'이 되돌아오지 않습니다 — 체크해도 저장되지 않습니다");
    }
  });

  test('이름이 서로 겹치지 않는다', () {
    final labels = Symptom.values.map((s) => s.label).toSet();
    expect(labels.length, Symptom.values.length);
  });

  test("화면의 '없음'은 증상이 아니다", () {
    // 행이 하나도 없는 상태가 곧 '없음'입니다. enum에 들어가면 저장됩니다.
    expect(Symptom.fromLabel('없음'), isNull);
  });
}
