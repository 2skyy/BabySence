import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project/features/mypage/baby_member_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 자격 증명 없이 확인할 수 있는 부분만 다룹니다.
/// 정책·만료·재사용 판단은 DB가 하며, supabase/migrations/004에서 검증했습니다.
void main() {
  group('초대 코드 표기', () {
    test('8자리를 4자씩 끊어 보여준다', () {
      expect(BabyMemberService.formatCode('DC3XC8ZT'), 'DC3XC8ZT'.replaceRange(4, 4, '-'));
      expect(BabyMemberService.formatCode('DC3XC8ZT'), 'DC3X-C8ZT');
    });

    test('길이가 다르면 그대로 둔다', () {
      // 서버가 8자리만 만들지만, 표기 때문에 화면이 깨지지는 않게 합니다.
      expect(BabyMemberService.formatCode('ABC'), 'ABC');
    });
  });

  group('입력 코드 정규화', () {
    test('하이픈·공백·소문자를 받아들인다', () {
      // 코드를 불러주고 받아 적는 방식이라 형태가 제각각입니다.
      for (final input in ['DC3X-C8ZT', 'dc3x c8zt', ' DC3XC8ZT ', 'dc3x-c8zt']) {
        expect(BabyMemberService.normalizeCode(input), 'DC3XC8ZT');
      }
    });

    test('알파벳과 숫자만 남긴다', () {
      expect(BabyMemberService.normalizeCode('DC3X_C8ZT!'), 'DC3XC8ZT');
    });
  });

  group('구성원 해석', () {
    Map<String, dynamic> row({
      String role = 'member',
      String? name,
      bool isMe = false,
    }) =>
        {
          'user_id': '22222222-2222-2222-2222-222222222222',
          'role': role,
          'joined_at': '2026-08-04T10:00:00+00:00',
          'name': name,
          'is_me': isMe,
        };

    test('owner를 소유자로 읽는다', () {
      // DB의 CHECK 제약(owner/member) 값을 그대로 씁니다.
      expect(BabyMember.fromMap(row(role: 'owner')).isOwner, isTrue);
      expect(BabyMember.fromMap(row()).isOwner, isFalse);
    });

    test('역할을 화면 문구로 바꾼다', () {
      expect(BabyMember.fromMap(row(role: 'owner')).roleLabel, '등록한 사람');
      expect(BabyMember.fromMap(row()).roleLabel, '함께 보는 사람');
    });

    test('이름이 없으면 빈칸 대신 기본 문구를 쓴다', () {
      // 프로필도 이메일도 없을 수 있어 DB가 null을 돌려줄 수 있습니다.
      expect(BabyMember.fromMap(row(name: null)).name, '보호자');
      expect(BabyMember.fromMap(row(name: '아빠')).name, '아빠');
    });

    test('참여 시각을 현지 시간으로 읽는다', () {
      final member = BabyMember.fromMap(row());
      expect(member.joinedAt.isUtc, isFalse);
      expect(member.joinedAt.toUtc(), DateTime.utc(2026, 8, 4, 10));
    });
  });

  group('오류 안내', () {
    test('DB가 적어 보낸 한국어 문구를 그대로 보여준다', () {
      // 만료·재사용 같은 판단은 SQL에 한국어로 적혀 있어 앱에서 다시 나누지 않습니다.
      final e = PostgrestException(message: '이미 사용된 초대 코드입니다.', code: 'P0001');
      expect(BabyMemberService.errorMessage(e), '이미 사용된 초대 코드입니다.');
    });

    test('그 밖의 오류는 뭉뚱그려 안내한다', () {
      expect(
        BabyMemberService.errorMessage(Exception('SocketException')),
        contains('다시 시도'),
      );
    });
  });
}
