import 'package:supabase_flutter/supabase_flutter.dart';

/// 약을 먹인 이유. enum 이름이 medication_records.reason의 CHECK 값과
/// 그대로 일치해야 합니다.
///
/// 자유 입력으로 두지 않은 이유는 **세기 위해서**입니다. '토함'/'구토'/'토'를
/// 각각 적으면 같은 증상이 몇 번 반복됐는지 셀 수 없습니다.
enum MedicationReason {
  fever('발열'),
  cough('기침'),
  runnyNose('콧물'),
  rash('발진'),
  vomit('구토'),
  diarrhea('설사'),
  prescription('처방약'),
  other('기타');

  const MedicationReason(this.label);

  final String label;

  /// DB에 넣는 값. enum 이름이 camelCase라 snake_case로 바꿔줍니다.
  ///
  /// `_ =>` 로 뭉뚱그리지 않고 전부 나열합니다. 그래야 나중에 항목을 추가할 때
  /// 컴파일이 막아 줍니다. 뭉뚱그리면 camelCase 이름이 그대로 나가서,
  /// CHECK 제약에서만 조용히 터집니다.
  String get dbValue => switch (this) {
        MedicationReason.fever => 'fever',
        MedicationReason.cough => 'cough',
        MedicationReason.runnyNose => 'runny_nose',
        MedicationReason.rash => 'rash',
        MedicationReason.vomit => 'vomit',
        MedicationReason.diarrhea => 'diarrhea',
        MedicationReason.prescription => 'prescription',
        MedicationReason.other => 'other',
      };

  /// DB에서 읽은 값을 되돌립니다. 나중에 CHECK에 항목이 추가돼도 조회가
  /// 깨지지 않도록 모르는 값은 [other]로 봅니다.
  static MedicationReason fromDbValue(String? value) {
    for (final r in MedicationReason.values) {
      if (r.dbValue == value) return r;
    }
    return MedicationReason.other;
  }
}

/// 병원에 간 이유. hospital_visits.reason의 CHECK 값과 일치해야 합니다.
enum VisitReason {
  fever('발열'),
  cough('기침'),
  runnyNose('콧물'),
  rash('발진'),
  vomit('구토'),
  diarrhea('설사'),
  checkup('정기검진'),
  vaccination('예방접종'),
  other('기타');

  const VisitReason(this.label);

  final String label;

  /// [MedicationReason.dbValue]와 같은 이유로 전부 나열합니다.
  String get dbValue => switch (this) {
        VisitReason.fever => 'fever',
        VisitReason.cough => 'cough',
        VisitReason.runnyNose => 'runny_nose',
        VisitReason.rash => 'rash',
        VisitReason.vomit => 'vomit',
        VisitReason.diarrhea => 'diarrhea',
        VisitReason.checkup => 'checkup',
        VisitReason.vaccination => 'vaccination',
        VisitReason.other => 'other',
      };

  static VisitReason fromDbValue(String? value) {
    for (final r in VisitReason.values) {
      if (r.dbValue == value) return r;
    }
    return VisitReason.other;
  }

  /// 증상 때문에 간 방문인가.
  ///
  /// 정기검진과 예방접종은 아파서 간 것이 아니므로 반복 집계에서 뺍니다.
  /// 넣으면 "3번 반복"이 검진 일정 때문에 늘어납니다.
  bool get isSymptom => this != VisitReason.checkup &&
      this != VisitReason.vaccination &&
      this != VisitReason.other;
}

/// medication_records 한 행.
class MedicationRecord {
  final String id;
  final String name;
  final String? dose;
  final MedicationReason reason;
  final DateTime takenAt;

  const MedicationRecord({
    required this.id,
    required this.name,
    required this.reason,
    required this.takenAt,
    this.dose,
  });

  factory MedicationRecord.fromMap(Map<String, dynamic> map) {
    return MedicationRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      dose: map['dose'] as String?,
      reason: MedicationReason.fromDbValue(map['reason'] as String?),
      takenAt: DateTime.parse(map['taken_at'] as String).toLocal(),
    );
  }

  /// 이력 목록에 보여줄 요약.
  String get summary {
    final parts = [name, if (dose != null && dose!.isNotEmpty) dose!];
    return '${parts.join(' ')} · ${reason.label}';
  }
}

/// hospital_visits 한 행.
class HospitalVisit {
  final String id;
  final String? hospitalName;
  final VisitReason reason;
  final String? note;
  final DateTime visitedAt;

  const HospitalVisit({
    required this.id,
    required this.reason,
    required this.visitedAt,
    this.hospitalName,
    this.note,
  });

  factory HospitalVisit.fromMap(Map<String, dynamic> map) {
    return HospitalVisit(
      id: map['id'] as String,
      hospitalName: map['hospital_name'] as String?,
      reason: VisitReason.fromDbValue(map['reason'] as String?),
      note: map['note'] as String?,
      visitedAt: DateTime.parse(map['visited_at'] as String).toLocal(),
    );
  }

  String get summary {
    final where = hospitalName;
    final head = where == null || where.isEmpty ? reason.label
        : '$where · ${reason.label}';
    final memo = note;
    return memo == null || memo.isEmpty ? head : '$head\n$memo';
  }
}

/// 같은 이유가 몇 번 반복됐는지.
///
/// 논문 3-2절 ⑥의 "반복적인 증상 발생 여부"입니다. **세기만 합니다** —
/// 며칠 안에 몇 번이면 이상인지에 대한 기준이 어느 출처에도 없어서
/// 정상/주의를 매기지 않습니다.
typedef ReasonCount = ({String label, int count});

/// medication_records · hospital_visits 접근.
class CareRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 반복을 세는 기간. 감기 한 번이 2~3주 가는 것을 감안해 넉넉히 둡니다.
  static const int repeatWindowDays = 90;

  // ── 약 복용 ──────────────────────────────────────────────────────────────

  static Future<List<MedicationRecord>> loadMedications(String babyId,
      {int limit = 20}) async {
    final rows = await _client
        .from('medication_records')
        .select()
        .eq('baby_id', babyId)
        .order('taken_at', ascending: false)
        .limit(limit);

    return rows.map(MedicationRecord.fromMap).toList();
  }

  /// medication_records에 넣을 행.
  ///
  /// 비어 있는 용량은 빈 문자열이 아니라 null로 넣습니다. 빈 문자열은
  /// "0ml을 먹였다"처럼 읽힐 수 있습니다.
  static Map<String, dynamic> buildMedicationRow({
    required String babyId,
    required String name,
    required MedicationReason reason,
    required DateTime takenAt,
    String? dose,
  }) {
    final trimmedDose = dose?.trim();
    return {
      'baby_id': babyId,
      'name': name.trim(),
      'dose': trimmedDose == null || trimmedDose.isEmpty ? null : trimmedDose,
      'reason': reason.dbValue,
      'taken_at': takenAt.toIso8601String(),
    };
  }

  static Future<void> saveMedication({
    required String babyId,
    required String name,
    required MedicationReason reason,
    required DateTime takenAt,
    String? dose,
  }) async {
    await _client.from('medication_records').insert(buildMedicationRow(
          babyId: babyId,
          name: name,
          reason: reason,
          takenAt: takenAt,
          dose: dose,
        ));
  }

  static Future<void> deleteMedication(String id) async {
    await _client.from('medication_records').delete().eq('id', id);
  }

  // ── 병원 방문 ────────────────────────────────────────────────────────────

  static Future<List<HospitalVisit>> loadVisits(String babyId,
      {int limit = 20}) async {
    final rows = await _client
        .from('hospital_visits')
        .select()
        .eq('baby_id', babyId)
        .order('visited_at', ascending: false)
        .limit(limit);

    return rows.map(HospitalVisit.fromMap).toList();
  }

  static Map<String, dynamic> buildVisitRow({
    required String babyId,
    required VisitReason reason,
    required DateTime visitedAt,
    String? hospitalName,
    String? note,
  }) {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return {
      'baby_id': babyId,
      'hospital_name': clean(hospitalName),
      'reason': reason.dbValue,
      'note': clean(note),
      'visited_at': visitedAt.toIso8601String(),
    };
  }

  static Future<void> saveVisit({
    required String babyId,
    required VisitReason reason,
    required DateTime visitedAt,
    String? hospitalName,
    String? note,
  }) async {
    await _client.from('hospital_visits').insert(buildVisitRow(
          babyId: babyId,
          reason: reason,
          visitedAt: visitedAt,
          hospitalName: hospitalName,
          note: note,
        ));
  }

  static Future<void> deleteVisit(String id) async {
    await _client.from('hospital_visits').delete().eq('id', id);
  }
}

/// 최근 [CareRecordService.repeatWindowDays]일 안에 **두 번 이상** 나온 이유.
///
/// 한 번뿐인 것은 반복이 아니므로 뺍니다. 많은 순으로 정렬합니다.
///
/// [now]를 받는 이유는 테스트에서 시간을 고정하기 위해서입니다.
List<ReasonCount> repeatedReasons({
  required List<MedicationRecord> medications,
  required List<HospitalVisit> visits,
  DateTime? now,
}) {
  final since = (now ?? DateTime.now())
      .subtract(const Duration(days: CareRecordService.repeatWindowDays));

  final counts = <String, int>{};

  void add(String label) => counts[label] = (counts[label] ?? 0) + 1;

  for (final m in medications) {
    if (m.takenAt.isBefore(since)) continue;
    // 처방약과 기타는 어떤 증상인지 알 수 없어 세지 않습니다.
    if (m.reason == MedicationReason.prescription ||
        m.reason == MedicationReason.other) {
      continue;
    }
    add(m.reason.label);
  }

  for (final v in visits) {
    if (v.visitedAt.isBefore(since)) continue;
    if (!v.reason.isSymptom) continue;
    add(v.reason.label);
  }

  final repeated = [
    for (final e in counts.entries)
      if (e.value >= 2) (label: e.key, count: e.value),
  ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      // 횟수가 같으면 이름순으로 둡니다. 순서가 매번 바뀌면 읽기 어렵습니다.
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });

  return repeated;
}
