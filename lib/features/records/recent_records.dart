import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';

/// 기록 종류. 목록에서 아이콘·색을 고르는 데 씁니다.
enum RecordKind {
  feeding('수유'),
  diaper('배변'),
  sleep('수면'),
  temperature('체온');

  const RecordKind(this.label);

  final String label;
}

/// 종류가 다른 기록들을 한 줄로 세우기 위한 공통 형태.
class RecentRecord {
  final RecordKind kind;
  final DateTime at;
  final String summary;

  const RecentRecord({
    required this.kind,
    required this.at,
    required this.summary,
  });
}

/// 네 종류의 기록을 시간 역순으로 합칩니다.
///
/// 각 서비스가 이미 최신순으로 주지만, 종류가 섞이면 순서가 무너지므로
/// 합친 뒤 다시 정렬합니다. 수면은 시작 시각을 기준으로 놓습니다 —
/// 아직 끝나지 않은 수면도 목록에 나와야 합니다.
List<RecentRecord> mergeRecentRecords({
  List<FeedingRecord> feedings = const [],
  List<DiaperRecord> diapers = const [],
  List<SleepRecord> sleeps = const [],
  List<TemperatureRecord> temperatures = const [],
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
  ];

  merged.sort((a, b) => b.at.compareTo(a.at));
  return merged.length <= limit ? merged : merged.sublist(0, limit);
}

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
