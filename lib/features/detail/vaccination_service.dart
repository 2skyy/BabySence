import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/db_time.dart';

/// vaccines 테이블의 한 행. 모든 사용자가 공유하는 읽기 전용 참조 데이터입니다.
class Vaccine {
  final int id;
  final String code;
  final String name;

  /// 화면 표시용 문구. 예: "생후 15~18개월"
  final String recommendedAgeLabel;

  /// 예정일 계산용 개월 수. scheduled_on = birth_date + N개월
  final int recommendedAgeMonths;

  final int doseNumber;

  const Vaccine({
    required this.id,
    required this.code,
    required this.name,
    required this.recommendedAgeLabel,
    required this.recommendedAgeMonths,
    required this.doseNumber,
  });

  factory Vaccine.fromMap(Map<String, dynamic> map) => Vaccine(
        id: map['id'] as int,
        code: map['code'] as String,
        name: map['name'] as String,
        recommendedAgeLabel: map['recommended_age_label'] as String,
        recommendedAgeMonths: map['recommended_age_months'] as int,
        doseNumber: map['dose_number'] as int,
      );
}

/// 표준 일정 하나와 우리 아이의 접종 여부를 합친 화면용 모델.
class VaccinationStatus {
  final Vaccine vaccine;

  /// 접종 완료일. null이면 아직 맞지 않았습니다.
  final DateTime? vaccinatedOn;

  /// 예정일. 기록이 없으면 생년월일 + 권장 개월 수로 계산합니다.
  final DateTime scheduledOn;

  const VaccinationStatus({
    required this.vaccine,
    required this.scheduledOn,
    this.vaccinatedOn,
  });

  bool get isDone => vaccinatedOn != null;

  /// 예정일이 지났는데 아직 맞지 않은 상태.
  ///
  /// **날짜로만 비교합니다.** [scheduledOn]은 자정인데 [now]는 현재 시각이라
  /// 그대로 견주면 접종일 당일 오전부터 '지남'이 됩니다. 같은 화면의 D-day는
  /// 날짜만 보고 '오늘'이라 적고 있어, 한 항목에 '오늘'과 빨간 '지남'이
  /// 함께 떴습니다.
  bool isOverdue(DateTime now) =>
      !isDone &&
      scheduledOn.isBefore(DateTime(now.year, now.month, now.day));
}

/// vaccines 조회 + vaccination_records 기록.
class VaccinationService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 생년월일에 개월 수를 더합니다.
  ///
  /// DateTime(2026, 1, 31)에 1개월을 더하면 Dart는 2026-03-03으로 넘기므로,
  /// 말일이 없는 달에서는 그 달의 마지막 날로 맞춰줍니다.
  static DateTime addMonths(DateTime date, int months) {
    final totalMonths = date.month + months;
    final year = date.year + (totalMonths - 1) ~/ 12;
    final month = (totalMonths - 1) % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day.clamp(1, lastDayOfMonth));
  }

  /// 표준 일정 전체와 우리 아이의 접종 이력을 합쳐 돌려줍니다.
  static Future<List<VaccinationStatus>> loadSchedule({
    required String babyId,
    required DateTime birthDate,
  }) async {
    final vaccineRows =
        await _client.from('vaccines').select().order('display_order');

    final recordRows = await _client
        .from('vaccination_records')
        .select()
        .eq('baby_id', babyId);

    // vaccine_id로 빠르게 찾도록 미리 정리합니다.
    final byVaccineId = <int, Map<String, dynamic>>{
      for (final r in recordRows) r['vaccine_id'] as int: r,
    };

    return [
      for (final row in vaccineRows)
        () {
          final vaccine = Vaccine.fromMap(row);
          final record = byVaccineId[vaccine.id];

          final vaccinatedOnRaw = record?['vaccinated_on'] as String?;
          final scheduledOnRaw = record?['scheduled_on'] as String?;

          return VaccinationStatus(
            vaccine: vaccine,
            scheduledOn: scheduledOnRaw != null
                ? DateTime.parse(scheduledOnRaw)
                : addMonths(birthDate, vaccine.recommendedAgeMonths),
            vaccinatedOn: vaccinatedOnRaw != null
                ? DateTime.parse(vaccinatedOnRaw)
                : null,
          );
        }(),
    ];
  }

  /// 접종 완료를 기록합니다.
  ///
  /// UNIQUE(baby_id, vaccine_id) 제약이 있어 같은 백신을 다시 누르면 오류 대신
  /// 기존 행을 갱신합니다(날짜 정정).
  static Future<void> markVaccinated({
    required String babyId,
    required int vaccineId,
    required DateTime vaccinatedOn,
    DateTime? scheduledOn,
  }) async {
    await _client.from('vaccination_records').upsert(
      {
        'baby_id': babyId,
        'vaccine_id': vaccineId,
        'scheduled_on': scheduledOn == null ? null : toDbDate(scheduledOn),
        'vaccinated_on': toDbDate(vaccinatedOn),
      },
      onConflict: 'baby_id,vaccine_id',
    );
  }

  /// 접종 기록을 취소합니다(잘못 누른 경우).
  static Future<void> unmarkVaccinated({
    required String babyId,
    required int vaccineId,
  }) async {
    await _client
        .from('vaccination_records')
        .delete()
        .eq('baby_id', babyId)
        .eq('vaccine_id', vaccineId);
  }
}
