import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';

/// 최근 7일 기록을 세어 놓은 것.
///
/// 여기서 나오는 숫자는 전부 실제로 남긴 기록을 센 값입니다. 추정하거나
/// 평균을 지어내지 않습니다 — 기록이 없으면 0이고, 0은 0으로 보여줍니다.
class WeeklySummary {
  final int feedingCount;
  final int diaperCount;

  /// 끝난 수면만 더합니다. 측정 중인 수면은 길이를 알 수 없습니다.
  final Duration sleepTotal;
  final int completedSleepCount;

  /// 기간 중 가장 높았던 체온. 기록이 없으면 null입니다.
  final double? highestTemperature;

  const WeeklySummary({
    required this.feedingCount,
    required this.diaperCount,
    required this.sleepTotal,
    required this.completedSleepCount,
    required this.highestTemperature,
  });

  static const days = 7;

  bool get isEmpty =>
      feedingCount == 0 &&
      diaperCount == 0 &&
      completedSleepCount == 0 &&
      highestTemperature == null;

  /// 하루 평균 수유 횟수. 7일로 나눕니다.
  double get feedingPerDay => feedingCount / days;

  /// 하루 평균 수면 시간. 끝난 수면만 반영하므로 실제보다 짧을 수 있습니다.
  Duration get sleepPerDay =>
      Duration(minutes: (sleepTotal.inMinutes / days).round());

  factory WeeklySummary.from({
    required List<FeedingRecord> feedings,
    required List<DiaperRecord> diapers,
    required List<SleepRecord> sleeps,
    required List<TemperatureRecord> temperatures,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    // 오늘을 포함해 7일. 6일 전 자정부터 셉니다.
    final today = DateTime(reference.year, reference.month, reference.day);
    final from = today.subtract(const Duration(days: days - 1));

    bool inRange(DateTime at) => !at.isBefore(from);

    var sleepTotal = Duration.zero;
    var completedSleeps = 0;
    for (final s in sleeps) {
      if (!inRange(s.startedAt)) continue;
      final d = s.duration;
      if (d == null) continue;
      sleepTotal += d;
      completedSleeps++;
    }

    double? highest;
    for (final t in temperatures) {
      if (!inRange(t.measuredAt)) continue;
      if (highest == null || t.temperatureC > highest) {
        highest = t.temperatureC;
      }
    }

    return WeeklySummary(
      feedingCount: feedings.where((r) => inRange(r.fedAt)).length,
      diaperCount: diapers.where((r) => inRange(r.recordedAt)).length,
      sleepTotal: sleepTotal,
      completedSleepCount: completedSleeps,
      highestTemperature: highest,
    );
  }
}

/// 시간을 '7시간 30분'처럼 씁니다. 0분이면 시간만 씁니다.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}
