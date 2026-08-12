import '../detail/care/care_record_service.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/growth/growth_record.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';

/// 기록 종류. 목록에서 아이콘·색을 고르는 데 씁니다.
enum RecordKind {
  feeding('수유'),
  diaper('배변'),
  sleep('수면'),
  temperature('체온'),
  growth('성장'),
  medication('약'),
  hospital('병원');

  const RecordKind(this.label);

  final String label;
}

/// 종류가 다른 기록들을 한 줄로 세우기 위한 공통 형태.
class RecentRecord {
  final RecordKind kind;
  final DateTime at;
  final String summary;

  /// 이 기록이 **시각까지** 아는지.
  ///
  /// 성장은 `recorded_on`이 `date` 컬럼이라 잰 시각을 모릅니다. 그런 기록에
  /// '오전 12:00'을 붙이면 자정에 쟀다는 뜻이 되어, 앱이 모르는 것을 지어내는
  /// 셈입니다. 날짜 묶음에는 넣되 시각은 비웁니다.
  final bool hasTime;

  const RecentRecord({
    required this.kind,
    required this.at,
    required this.summary,
    this.hasTime = true,
  });
}

/// 남긴 기록들을 시간 역순으로 합칩니다.
///
/// 각 서비스가 이미 최신순으로 주지만, 종류가 섞이면 순서가 무너지므로
/// 합친 뒤 다시 정렬합니다. 수면은 시작 시각을 기준으로 놓습니다 —
/// 아직 끝나지 않은 수면도 목록에 나와야 합니다.
///
/// 예방접종은 담지 않습니다. `vaccinated_on`이 날짜뿐이라 시각이 없고,
/// 목록에 넣으려면 표준 일정 전체를 함께 읽어야 해서 조회가 두 번 늘어납니다.
/// 접종 이력은 예방접종 화면이 일정과 나란히 보여주는 편이 읽기 좋습니다.
List<RecentRecord> mergeRecentRecords({
  List<FeedingRecord> feedings = const [],
  List<DiaperRecord> diapers = const [],
  List<SleepRecord> sleeps = const [],
  List<TemperatureRecord> temperatures = const [],
  List<GrowthRecord> growths = const [],
  List<MedicationRecord> medications = const [],
  List<HospitalVisit> visits = const [],
  int limit = 30,
}) {
  final merged = <RecentRecord>[
    for (final r in feedings)
      RecentRecord(kind: RecordKind.feeding, at: r.fedAt, summary: r.summary),
    for (final r in diapers)
      RecentRecord(kind: RecordKind.diaper, at: r.recordedAt, summary: r.summary),
    for (final r in sleeps)
      RecentRecord(kind: RecordKind.sleep, at: r.startedAt, summary: r.summary),
    for (final r in temperatures)
      RecentRecord(
        kind: RecordKind.temperature,
        at: r.measuredAt,
        summary: r.summary,
      ),
    for (final r in growths)
      RecentRecord(
        kind: RecordKind.growth,
        at: r.date,
        summary: growthSummary(r),
        hasTime: false,
      ),
    for (final r in medications)
      RecentRecord(
        kind: RecordKind.medication,
        at: r.takenAt,
        summary: r.summary,
      ),
    for (final r in visits)
      RecentRecord(
        kind: RecordKind.hospital,
        at: r.visitedAt,
        summary: r.summary,
      ),
  ];

  merged.sort((a, b) => b.at.compareTo(a.at));
  return merged.length <= limit ? merged : merged.sublist(0, limit);
}

/// 성장 기록 한 줄. 키와 몸무게 중 적은 쪽만 남길 수도 있습니다.
String growthSummary(GrowthRecord record) => [
      if (record.heightCm != null) '키 ${record.heightCm!.toStringAsFixed(1)}cm',
      if (record.weightKg != null)
        '몸무게 ${record.weightKg!.toStringAsFixed(1)}kg',
    ].join(' · ');

/// 목록을 날짜별로 묶습니다. 키는 그 날의 자정입니다.
///
/// 하루치가 이어져 보여야 "어제는 몇 번 먹였지"를 셀 수 있습니다.
Map<DateTime, List<RecentRecord>> groupByDay(List<RecentRecord> records) {
  final grouped = <DateTime, List<RecentRecord>>{};
  for (final r in records) {
    final day = DateTime(r.at.year, r.at.month, r.at.day);
    grouped.putIfAbsent(day, () => []).add(r);
  }
  return grouped;
}

/// 줄 오른쪽에 붙는 시각. 날짜는 머리글이 이미 알려주므로 시각만 씁니다.
String formatTimeOfDay(DateTime at) {
  final period = at.hour < 12 ? '오전' : '오후';
  // 0시는 오전 12시, 13시는 오후 1시로 표기합니다.
  final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '$period $hour12:${at.minute.toString().padLeft(2, '0')}';
}

/// 날짜 머리글. 오늘·어제는 이름으로 부릅니다.
String formatDayHeader(DateTime day, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '${day.month}월 ${day.day}일';
}
