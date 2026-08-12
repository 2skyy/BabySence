import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/baby_service.dart';
import 'package:flutter_project/core/services/growth_calculator.dart';

/// 아이 정보를 고칠 길이 아예 없었습니다. 생년월일은 체온·성장 판정의
/// 기준이라, 잘못 넣으면 판정도 계속 틀린 채로 남습니다.
void main() {
  group('buildUpdate', () {
    test('이름·성별·생년월일만 보낸다', () {
      final row = BabyService.buildUpdate(
        name: '유승환',
        sex: ChildSex.male,
        birthDate: DateTime(2026, 3, 1),
      );

      expect(row, {'name': '유승환', 'sex': 'male', 'birth_date': '2026-03-01'});
    });

    test('user_id를 보내지 않는다', () {
      // 바꿀 이유가 없고, 보내면 RLS의 with check에 걸릴 여지만 생깁니다.
      final row = BabyService.buildUpdate(
        name: 'a',
        sex: ChildSex.female,
        birthDate: DateTime(2026, 1, 2),
      );

      expect(row.containsKey('user_id'), isFalse);
      expect(row.containsKey('id'), isFalse);
      expect(row.containsKey('created_at'), isFalse);
    });

    test('이름 앞뒤 공백을 지운다', () {
      final row = BabyService.buildUpdate(
        name: '  유승환  ',
        sex: ChildSex.male,
        birthDate: DateTime(2026, 3, 1),
      );
      expect(row['name'], '유승환');
    });

    test('생년월일을 UTC로 바꾸지 않는다', () {
      // birth_date는 date 컬럼입니다. toUtc()를 태우면 한국 시간 오전에 적은
      // 날짜가 하루 앞으로 밀립니다.
      final row = BabyService.buildUpdate(
        name: 'a',
        sex: ChildSex.male,
        birthDate: DateTime(2026, 3, 1, 8, 30),
      );
      expect(row['birth_date'], '2026-03-01');
    });
  });

  test('아이 정보를 고칠 길이 화면에 있다', () {
    // 등록만 있고 수정이 없던 상태로 되돌아가지 않게 막습니다.
    final mypage =
        File('lib/features/mypage/mypage_page.dart').readAsStringSync();
    expect(mypage.contains('BabyEditPage'), isTrue,
        reason: '마이페이지의 아이 카드에서 수정 화면으로 갈 수 있어야 합니다');

    final home = File('lib/features/home/home_page.dart').readAsStringSync();
    expect(home.contains('AppRoutes.mypage'), isTrue,
        reason: '홈 앱바의 이름을 누르면 마이페이지로 가야 합니다');
  });

  test('온보딩이 키도 받는다', () {
    // 키가 없으면 신장 곡선을 그릴 수 없습니다.
    final onboarding =
        File('lib/features/onboarding/child_info_page.dart').readAsStringSync();
    expect(onboarding.contains('_heightController'), isTrue);
    expect(onboarding.contains('heightCm:'), isTrue,
        reason: '입력받은 키가 성장 기록으로 저장돼야 합니다');
  });
}
