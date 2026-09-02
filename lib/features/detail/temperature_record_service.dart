import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

/// 동반 증상. enum 이름이 temperature_symptoms.symptom의 CHECK 제약
/// (`cough` / `runny_nose` / `rash` / `vomit` / `diarrhea`)과 일치해야 합니다.
///
/// UI의 '없음'은 여기에 없습니다. 행이 하나도 없는 상태가 곧 '없음'입니다.
enum Symptom {
  cough('기침'),
  runnyNose('콧물'),
  rash('발진'),
  vomit('구토'),
  diarrhea('설사');

  const Symptom(this.label);

  final String label;

  /// DB에 넣는 값. enum 이름이 camelCase라 snake_case로 바꿔줍니다.
  String get dbValue => switch (this) {
        Symptom.cough => 'cough',
        Symptom.runnyNose => 'runny_nose',
        Symptom.rash => 'rash',
        Symptom.vomit => 'vomit',
        Symptom.diarrhea => 'diarrhea',
      };

  /// 화면의 한글 라벨을 되돌립니다. '없음'이나 알 수 없는 값은 null입니다.
  static Symptom? fromLabel(String label) {
    for (final s in Symptom.values) {
      if (s.label == label) return s;
    }
    return null;
  }

  /// DB에서 읽은 값을 되돌립니다. 알 수 없는 값은 null입니다
  /// (나중에 CHECK 제약에 항목이 추가되어도 조회가 깨지지 않게).
  static Symptom? fromDbValue(String? value) {
    if (value == null) return null;
    for (final s in Symptom.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}

/// temperature_records 한 행 + 함께 기록된 증상.
class TemperatureRecord {
  final String id;
  final double temperatureC;
  final DateTime measuredAt;
  final List<Symptom> symptoms;

  const TemperatureRecord({
    required this.id,
    required this.temperatureC,
    required this.measuredAt,
    this.symptoms = const [],
  });

  factory TemperatureRecord.fromMap(Map<String, dynamic> map) {
    // 중첩 select로 함께 가져온 증상 행들입니다.
    final raw = (map['temperature_symptoms'] as List?) ?? const [];
    final symptoms = <Symptom>[];
    for (final s in raw) {
      final value = (s as Map)['symptom'] as String?;
      final parsed = Symptom.fromDbValue(value);
      if (parsed != null) symptoms.add(parsed);
    }

    return TemperatureRecord(
      id: map['id'] as String,
      temperatureC: (map['temperature_c'] as num).toDouble(),
      measuredAt: DateTime.parse(map['measured_at'] as String).toLocal(),
      symptoms: symptoms,
    );
  }

  /// 이력 목록에 보여줄 요약. 증상이 없으면 체온만 보여줍니다.
  String get summary {
    final temp = '${temperatureC.toStringAsFixed(1)}℃';
    if (symptoms.isEmpty) return temp;
    return '$temp · ${symptoms.map((s) => s.label).join(', ')}';
  }
}

/// temperature_records + temperature_symptoms 테이블 접근.
class TemperatureRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 최근 기록을 증상과 함께 가져옵니다.
  /// 최근 체온 기록.
  ///
  /// [since]를 주면 그 시각 이후만 읽습니다. **기간을 말하는 화면은 반드시
  /// 이걸 써야 합니다** — 기본 [limit]에만 기대면 "최근 3일"이라 적어 두고
  /// 실제로는 최신 20건만 보게 됩니다. 열이 나서 자주 잰 아이일수록 그 창의
  /// 앞쪽(첫날 고열)이 빠지는데, 하필 가장 알고 싶은 값입니다.
  ///
  /// [until]을 주면 그 시각 **앞**까지만 읽습니다. 상한이 없으면 [limit]이
  /// 오늘 쪽부터 채워져, 지난 기간을 펴 본 화면에는 그 기간 기록이 한 건도
  /// 오지 않습니다 — 화면은 그것을 '기록 없음'으로 읽습니다.
  static Future<List<TemperatureRecord>> loadRecent(
    String babyId, {
    int limit = 20,
    DateTime? since,
    DateTime? until,
  }) async {
    var query = _client
        .from('temperature_records')
        // 증상은 별도 테이블이라 중첩 select로 한 번에 읽습니다.
        .select('*, temperature_symptoms(symptom)')
        .eq('baby_id', babyId);

    if (since != null) query = query.gte('measured_at', toDbTime(since));
    if (until != null) query = query.lt('measured_at', toDbTime(until));

    final rows =
        await query.order('measured_at', ascending: false).limit(limit);

    return rows.map(TemperatureRecord.fromMap).toList();
  }

  static Future<void> delete(String id) async {
    // temperature_symptoms는 ON DELETE CASCADE라 함께 지워집니다.
    await _client.from('temperature_records').delete().eq('id', id);
  }

  /// temperature_records에 넣을 행.
  static Map<String, dynamic> buildRecordRow({
    required String babyId,
    required double temperatureC,
    required DateTime measuredAt,
  }) {
    return {
      'baby_id': babyId,
      'temperature_c': temperatureC,
      'measured_at': toDbTime(measuredAt),
    };
  }

  /// temperature_symptoms에 넣을 행들.
  ///
  /// 증상이 없으면 **빈 목록**입니다. UI의 '없음'을 저장하지 않기 때문이며,
  /// 행이 하나도 없는 상태가 곧 '없음'입니다.
  /// 같은 증상을 두 번 고르면 복합 PK를 위반하므로 중복을 제거합니다.
  static List<Map<String, dynamic>> buildSymptomRows({
    required String recordId,
    required List<Symptom> symptoms,
  }) {
    return [
      for (final s in symptoms.toSet())
        {'temperature_record_id': recordId, 'symptom': s.dbValue},
    ];
  }

  /// 체온과 동반 증상을 저장합니다.
  ///
  /// 증상은 다중 선택이라 별도 테이블에 여러 행으로 들어갑니다. 먼저 체온 행을
  /// 만들고 그 id로 증상을 넣습니다.
  /// 체온과 동반 증상을 저장합니다.
  ///
  /// 두 표에 나눠 넣어야 해서 **한 번에 끝나지 않습니다.** 증상 저장이
  /// 실패했을 때 통째로 예외를 던지면, 체온은 이미 들어갔는데 화면은
  /// "저장하지 못했습니다"라고 말합니다. 사용자가 다시 누르면 같은 체온이
  /// 한 번 더 쌓입니다.
  ///
  /// 그래서 증상 실패는 **예외 대신 결과로** 알립니다. 판정 저장이 이미
  /// 그렇게 돼 있습니다 — 곁다리가 실패했다고 본체를 무효로 만들지 않습니다.
  ///
  /// 돌려주는 값이 false면 체온만 저장된 것입니다.
  static Future<bool> save({
    required String babyId,
    required double temperatureC,
    required DateTime measuredAt,
    List<Symptom> symptoms = const [],
  }) async {
    final row = await _client
        .from('temperature_records')
        .insert(buildRecordRow(
          babyId: babyId,
          temperatureC: temperatureC,
          measuredAt: measuredAt,
        ))
        .select()
        .single();

    final symptomRows = buildSymptomRows(
      recordId: row['id'] as String,
      symptoms: symptoms,
    );
    if (symptomRows.isEmpty) return true;

    try {
      await _client.from('temperature_symptoms').insert(symptomRows);
      return true;
    } catch (e) {
      debugPrint('동반 증상 저장 실패: $e');
      return false;
    }
  }
}
