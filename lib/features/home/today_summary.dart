import '../detail/diaper_record_service.dart';
import '../../core/services/duration_text.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';

/// 홈 화면 타일에 보여줄 오늘의 마지막 기록 요약.
///
/// 값이 없으면 null입니다. 화면은 null일 때 '기록 없음'을 보여줍니다.
/// 없는 데이터를 그럴듯한 예시로 채우면 사용자가 자기 기록으로 오해합니다.
class TodaySummary {
  final FeedingRecord? feeding;
  final TemperatureRecord? temperature;
  final DiaperRecord? diaper;
  final SleepRecord? sleep;

  const TodaySummary({
    this.feeding,
    this.temperature,
    this.diaper,
    this.sleep,
  });

  static const empty = TodaySummary();

  /// 오늘 안에 있는 기록인지 봅니다.
  static bool isToday(DateTime at, DateTime now) =>
      at.year == now.year && at.month == now.month && at.day == now.day;

  /// 각 서비스가 최신순으로 준 목록에서 오늘 것 중 가장 최근 하나를 고릅니다.
  ///
  /// 수면은 시작 시각이 어제라도(밤잠) 오늘로 이어지므로 종료 시각도 함께 봅니다.
  factory TodaySummary.from({
    required List<FeedingRecord> feedings,
    required List<TemperatureRecord> temperatures,
    required List<DiaperRecord> diapers,
    required List<SleepRecord> sleeps,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    T? firstToday<T>(List<T> list, DateTime Function(T) at) {
      for (final item in list) {
        if (isToday(at(item), today)) return item;
      }
      return null;
    }

    SleepRecord? recentSleep;
    for (final s in sleeps) {
      final ended = s.endedAt;
      if (isToday(s.startedAt, today) ||
          (ended != null && isToday(ended, today))) {
        recentSleep = s;
        break;
      }
    }

    return TodaySummary(
      feeding: firstToday(feedings, (r) => r.fedAt),
      temperature: firstToday(temperatures, (r) => r.measuredAt),
      diaper: firstToday(diapers, (r) => r.recordedAt),
      sleep: recentSleep,
    );
  }

  /// 타일에 쓸 문구. 기록이 없으면 null을 돌려주고 화면이 '기록 없음'을 씁니다.
  String? get feedingLabel => feeding?.summary;
  String? get temperatureLabel =>
      temperature == null ? null : '${temperature!.temperatureC.toStringAsFixed(1)}℃';
  String? get diaperLabel => diaper?.summary;

  String? get sleepLabel {
    final s = sleep;
    if (s == null) return null;
    if (s.endedAt == null) return '${s.type.label} 측정 중';
    final d = s.duration!;
    return '${s.type.label} ${formatDuration(d)}';
  }

  /// 오늘 기록이 하나라도 있는지. 없으면 홈의 요약 카드를 숨깁니다.
  bool get hasAny =>
      feeding != null || temperature != null || diaper != null || sleep != null;
}
