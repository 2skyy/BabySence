import 'package:supabase_flutter/supabase_flutter.dart';

/// 한 아이를 함께 보는 보호자.
class BabyMember {
  final String userId;

  /// `owner`는 아이를 등록한 사람. 초대와 아이 삭제를 할 수 있습니다.
  final String role;
  final DateTime joinedAt;
  final String name;

  /// 지금 로그인한 사람인지. 목록에서 '나'를 표시하는 데 씁니다.
  final bool isMe;

  const BabyMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.name,
    required this.isMe,
  });

  bool get isOwner => role == 'owner';

  factory BabyMember.fromMap(Map<String, dynamic> map) => BabyMember(
        userId: map['user_id'] as String,
        role: map['role'] as String,
        joinedAt: DateTime.parse(map['joined_at'] as String).toLocal(),
        name: (map['name'] as String?) ?? '보호자',
        isMe: (map['is_me'] as bool?) ?? false,
      );

  String get roleLabel => isOwner ? '등록한 사람' : '함께 보는 사람';
}

/// 함께 키우기(구성원·초대) 접근.
///
/// 권한 판단은 전부 DB가 합니다. 초대 코드 발급은 소유자만, 수락은
/// `accept_baby_invite` 함수만 통과할 수 있어 앱에서 따로 막지 않습니다.
/// 자세한 정책은 supabase/migrations/004_add_baby_sharing.sql 참고.
class BabyMemberService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 사람이 불러주기 쉽도록 4자씩 끊어 보여줍니다. (ABCD-1234)
  static String formatCode(String code) {
    final c = code.trim().toUpperCase();
    if (c.length != 8) return c;
    return '${c.substring(0, 4)}-${c.substring(4)}';
  }

  /// 입력받은 코드를 서버가 기대하는 형태로 되돌립니다.
  /// 사용자가 하이픈·공백·소문자를 섞어 넣어도 받아들입니다.
  static String normalizeCode(String input) =>
      input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  static Future<List<BabyMember>> loadMembers(String babyId) async {
    final rows = await _client.rpc(
      'list_baby_members',
      params: {'p_baby_id': babyId},
    ) as List;

    return rows
        .map((r) => BabyMember.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// 초대 코드를 만들어 돌려줍니다. 소유자가 아니면 서버가 거부합니다.
  static Future<String> createInvite(String babyId, {int validDays = 7}) async {
    final code = await _client.rpc(
      'create_baby_invite',
      params: {'p_baby_id': babyId, 'p_valid_days': validDays},
    );
    return code as String;
  }

  /// 코드를 수락하고 참여한 아이 id를 돌려줍니다.
  ///
  /// 만료·재사용·중복 참여는 서버가 판단해 오류를 던집니다.
  static Future<String> acceptInvite(String code) async {
    final babyId = await _client.rpc(
      'accept_baby_invite',
      params: {'p_code': normalizeCode(code)},
    );
    return babyId as String;
  }

  /// 함께 보기를 그만둡니다. 소유자는 나갈 수 없습니다(정책이 막습니다).
  ///
  /// 소유자가 다른 구성원을 내보낼 때도 같은 호출을 씁니다. 누가 지울 수
  /// 있는지는 baby_members의 delete 정책이 판단합니다.
  static Future<void> removeMember({
    required String babyId,
    required String userId,
  }) async {
    await _client
        .from('baby_members')
        .delete()
        .eq('baby_id', babyId)
        .eq('user_id', userId);
  }

  /// DB 함수가 던진 안내 문구를 그대로 씁니다.
  ///
  /// '만료된 초대 코드입니다.' 같은 메시지는 SQL에서 한국어로 적어 두었으므로
  /// 앱에서 다시 분기하지 않습니다. 그 외의 오류만 뭉뚱그려 안내합니다.
  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return '처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }
}
