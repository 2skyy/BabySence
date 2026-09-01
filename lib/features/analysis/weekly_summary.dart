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

  /// 각 항목을 **실제로 기록한 날 수**.
  ///
  /// 하루 평균을 낼 때 7로 나누지 않고 이 값으로 나눕니다. 오늘 가입해
  /// 다섯 번 수유한 보호자에게 "하루 평균 0.7회"라고 말하던 자리입니다 —
  /// 기록이 없는 엿새를 0으로 세는 것은 이 파일이 스스로 적어 둔
  /// "평균을 지어내지 않는다"에 어긋납니다.
  final int feedingDays;
  final int diaperDays;
  final int sleepDays;

  /// 끝난 수면만 더합니다. 측정 중인 수면은 길이를 알 수 없습니다.
  final Duration sleepTotal;
  final int completedSleepCount;

  /// 창 안의 수면 행 수. **끝나지 않은 것도 셉니다.**
  ///
  /// [isEmpty]가 [completedSleepCount]만 보면, 밤잠을 재는 중인 신규
  /// 사용자에게 "최근 7일 동안 남긴 기록이 없습니다"가 뜹니다 — 기록 탭은
  /// 같은 행을 '밤잠 · 측정 중'으로 보여주는데요. 두 탭이 같은 주에 대해
  /// 반대말을 했습니다.
  final int sleepEntryCount;

  /// 기간 중 가장 높았던 체온. 기록이 없으면 null입니다.
  final double? highestTemperature;

  const WeeklySummary({
    required this.feedingCount,
    required this.diaperCount,
    required this.feedingDays,
    required this.diaperDays,
    required this.sleepDays,
    required this.sleepTotal,
    required this.completedSleepCount,
    required this.sleepEntryCount,
    required this.highestTemperature,
  });

  static const days = 7;

  bool get isEmpty =>
      feedingCount == 0 &&
      diaperCount == 0 &&
      sleepEntryCount == 0 &&
      highestTemperature == null;

  /// 하루 평균 수유 횟수. **기록한 날 수**로 나눕니다.
  double get feedingPerDay =>
      feedingDays == 0 ? 0 : feedingCount / feedingDays;

  /// 하루 평균 배변 횟수. **기록한 날 수**로 나눕니다.
  double get diaperPerDay => diaperDays == 0 ? 0 : diaperCount / diaperDays;

  /// 하루 평균 수면 시간. 끝난 수면만 반영하므로 실제보다 짧을 수 있습니다.
  Duration get sleepPerDay => sleepDays == 0
      ? Duration.zero
      : Duration(minutes: (sleepTotal.inMinutes / sleepDays).round());

  /// 평균 옆에 붙일 근거. "며칠을 근거로 낸 값인가"를 밝힙니다.
  ///
  /// 기록이 없으면 '기록한 0일 기준'이 아니라 아무 말도 하지 않습니다 —
  /// 나눌 것이 없는데 '하루 평균 0.0회'라고 적는 것은 숫자를 지어내는 쪽에
  /// 가깝습니다.
  static String? basis(int recordedDays) {
    if (recordedDays == 0) return null;
    return recordedDays >= days ? '$days일 기준' : '기록한 $recordedDays일 기준';
  }

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

    // 날짜만 남겨 중복을 지웁니다. 같은 날 열 번 먹여도 하루입니다.
    //
    // **시간 차가 아니라 달력 차로 셉니다.** difference().inDays는 절대
    // 시간을 재므로, 서머타임이 낀 주에는 하루가 23시간이나 25시간이 되어
    // 이웃한 두 날이 같은 값을 받습니다. 그러면 '기록한 6일'이 되고 하루
    // 평균이 부풀어 오릅니다. (한국은 서머타임이 없어 드러나지 않습니다.)
    // 달력 날짜 자체를 키로 씁니다(20260813). 어떤 뺄셈도 하지 않으므로
    // 시간대·서머타임과 무관합니다.
    int dayKey(DateTime at) => at.year * 10000 + at.month * 100 + at.day;

    var sleepTotal = Duration.zero;
    var completedSleeps = 0;
    var sleepEntries = 0;
    final sleepDates = <int>{};
    for (final s in sleeps) {
      if (!inRange(s.startedAt)) continue;
      // 끝나지 않은 것도 '기록이 있다'로는 셉니다.
      sleepEntries++;
      final d = s.duration;
      if (d == null) continue;
      sleepTotal += d;
      completedSleeps++;
      sleepDates.add(dayKey(s.startedAt));
    }

    final feedingsInRange = feedings.where((r) => inRange(r.fedAt)).toList();
    final diapersInRange = diapers.where((r) => inRange(r.recordedAt)).toList();

    double? highest;
    for (final t in temperatures) {
      if (!inRange(t.measuredAt)) continue;
      if (highest == null || t.temperatureC > highest) {
        highest = t.temperatureC;
      }
    }

    return WeeklySummary(
      feedingCount: feedingsInRange.length,
      diaperCount: diapersInRange.length,
      feedingDays: feedingsInRange.map((r) => dayKey(r.fedAt)).toSet().length,
      diaperDays:
          diapersInRange.map((r) => dayKey(r.recordedAt)).toSet().length,
      sleepDays: sleepDates.length,
      sleepTotal: sleepTotal,
      sleepEntryCount: sleepEntries,
      completedSleepCount: completedSleeps,
      highestTemperature: highest,
    );
  }
}
