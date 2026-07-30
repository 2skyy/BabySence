import 'package:supabase_flutter/supabase_flutter.dart';

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
    final temp = '${temperatureC.toStringAsFixed(1)}°C';
    if (symptoms.isEmpty) return temp;
    return '$temp · ${symptoms.map((s) => s.label).join(', ')}';
  }
}

/// temperature_records + temperature_symptoms 테이블 접근.
class TemperatureRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 최근 기록을 증상과 함께 가져옵니다.
  static Future<List<TemperatureRecord>> loadRecent(String babyId,
      {int limit = 20}) async {
    final rows = await _client
        .from('temperature_records')
        // 증상은 별도 테이블이라 중첩 select로 한 번에 읽습니다.
        .select('*, temperature_symptoms(symptom)')
        .eq('baby_id', babyId)
        .order('measured_at', ascending: false)
        .limit(limit);

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
      'measured_at': measuredAt.toIso8601String(),
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
  static Future<void> save({
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
    if (symptomRows.isEmpty) return;

    await _client.from('temperature_symptoms').insert(symptomRows);
  }
}
