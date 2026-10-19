import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/baby_service.dart';

void main() {
  group('알림에 부를 이름', () {
    test('앞뒤 공백을 다듬는다', () {
      expect(trimmedBabyName(' 지호 '), '지호');
      expect(trimmedBabyName('지호'), '지호');
    });

    test('없거나 비었으면 없는 것으로 본다', () {
      // 이름을 모를 때 '아이'처럼 지어내지 않습니다. 여기서 null을 돌려주면
      // 알림 제목이 이름 없이 나갑니다.
      expect(trimmedBabyName(null), isNull);
      expect(trimmedBabyName(''), isNull);
      expect(trimmedBabyName('   '), isNull);
      expect(trimmedBabyName('\t\n'), isNull);
    });

    test('가운데 공백은 그대로 둔다', () {
      // 이름에 띄어쓰기가 있을 수 있습니다.
      expect(trimmedBabyName(' 김 지호 '), '김 지호');
    });
  });
}
