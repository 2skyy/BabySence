import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

import 'growth_calculator.dart';

/// babies 테이블의 한 행. 모든 기록 테이블이 이 id(baby_id)를 참조합니다.
class Baby {
  final String id;
  final String name;
  final ChildSex sex;
  final DateTime birthDate;

  const Baby({
    required this.id,
    required this.name,
    required this.sex,
    required this.birthDate,
  });

  factory Baby.fromMap(Map<String, dynamic> map) => Baby(
        id: map['id'] as String,
        name: map['name'] as String,
        // DB의 CHECK 제약(male/female)이 ChildSex enum 이름과 일치합니다.
        sex: ChildSex.values.byName(map['sex'] as String),
        birthDate: DateTime.parse(map['birth_date'] as String),
      );
}

class BabyService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 현재 로그인한 사용자의 아이를 가져옵니다.
  ///
  /// 테이블 설계상 한 보호자가 여러 아이를 가질 수 있지만, 지금 화면들은
  /// 아이 한 명을 전제로 만들어져 있어 가장 먼저 등록한 아이를 씁니다.
  /// RLS가 본인 소유 행만 돌려주므로 user_id 조건을 따로 걸지 않습니다.
  static Future<Baby?> loadCurrent() async {
    final rows = await _client
        .from('babies')
        .select()
        .order('created_at')
        .limit(1);

    if (rows.isEmpty) return null;
    return Baby.fromMap(rows.first);
  }

  static Future<Baby> create({
    required String name,
    required ChildSex sex,
    required DateTime birthDate,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final row = await _client
        .from('babies')
        .insert({
          'user_id': userId,
          'name': name,
          'sex': sex.name,
          'birth_date': toDbDate(birthDate),
        })
        .select()
        .single();

    return Baby.fromMap(row);
  }

  /// 수정할 값. 전송과 분리해 자격증명 없이 검증할 수 있게 합니다.
  ///
  /// `user_id`는 넣지 않습니다. 바꿀 이유가 없고, 보내면 RLS의 with check에
  /// 걸릴 여지만 생깁니다(커뮤니티의 buildPostUpdate와 같은 이유).
  static Map<String, dynamic> buildUpdate({
    required String name,
    required ChildSex sex,
    required DateTime birthDate,
  }) {
    return {
      'name': name.trim(),
      'sex': sex.name,
      'birth_date': toDbDate(birthDate),
    };
  }

  /// 아이 정보를 고칩니다.
  ///
  /// 생년월일이 바뀌면 **이미 저장된 판정은 그대로 남습니다.** 판정은 잴 때의
  /// 개월 수로 계산한 값이고, 근거를 inputs에 함께 적어 두었기 때문입니다.
  /// 지난 판정을 새 생일로 다시 계산하면 그때 보여준 안내와 기록이 어긋납니다.
  ///
  /// RLS가 본인 것만 허용하므로 앱에서 권한을 따로 검사하지 않습니다.
  /// 남의 아이에 시도하면 0건이 바뀌고 select().single()이 예외를 던집니다.
  static Future<Baby> update({
    required String id,
    required String name,
    required ChildSex sex,
    required DateTime birthDate,
  }) async {
    final row = await _client
        .from('babies')
        .update(buildUpdate(name: name, sex: sex, birthDate: birthDate))
        .eq('id', id)
        .select()
        .single();

    return Baby.fromMap(row);
  }
}
