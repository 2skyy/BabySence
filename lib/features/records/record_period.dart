import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_service.dart';

/// 기록 화면이 그리는 하루의 모양. **위젯이 없는 계산만** 있습니다.
///
/// 하루를 원 하나로 봅니다 — 방학 생활계획표와 같은 24시간 원입니다.
/// 수면은 호(arc), 수유·배변은 둘레의 점입니다. 일·주·월 중 어느 눈금으로
/// 보든 원 하나의 내용은 같고, 몇 개를 늘어놓느냐만 달라집니다.
///
/// 그리는 코드와 떼어 놓은 이유는 **자정을 넘는 밤잠** 때문입니다. 오후 8시에
/// 재워 새벽 6시에 깬 잠은 한 원에 담기지 않고 두 날로 잘려야 합니다. 이
/// 계산이 이 화면에서 가장 틀리기 쉬운 곳이라 테스트로 확인합니다.
///
/// 원에는 수면·수유·배변만 그립니다. 체온·성장·약·병원은 하루에 여러 번
/// 반복되지 않아 '패턴'이 되지 않고, 넣으면 원이 점으로 뒤덮여 밤잠이
/// 안 보입니다. 그것들은 아래 목록이 맡습니다.

/// 한 번에 보는 눈금.
///
/// **선언 순서가 곧 버튼 순서입니다.** 넓은 것에서 좁은 것으로 갑니다.
enum PeriodMode {
  month('월'),
  week('주'),
  day('일');

  const PeriodMode(this.label);

  /// 버튼에 적히는 한 글자.
  final String label;
}

/// 보고 있는 기간. 하루·한 주(월~일)·한 달 중 하나입니다.
///
/// 달력 계산에 `add`/`subtract(Duration(days:))`를 쓰지 않습니다. 절대 시간을
/// 더하는 것이라 서머타임이 낀 구간에서는 자정이 23시나 1시로 밀립니다. 대신
/// `DateTime(y, m, d + n)`으로 **달력 날짜 자체**를 옮깁니다 — 생성자가 범위를
/// 넘는 값을 알아서 정규화하고(12월 32일 → 1월 1일), 어느 시간대에서도
/// 자정은 자정입니다. (한국은 서머타임이 없어 지금은 드러나지 않습니다.)
class RecordPeriod {
  final PeriodMode mode;

  /// 구간 첫날의 자정. 주는 월요일, 달은 1일입니다.
  final DateTime start;

  const RecordPeriod(this.mode, this.start);

  /// [day]가 속한 구간.
  factory RecordPeriod.of(PeriodMode mode, DateTime day) {
    return switch (mode) {
      PeriodMode.day => RecordPeriod(mode, DateTime(day.year, day.month, day.day)),
      // DateTime.weekday는 월요일이 1, 일요일이 7입니다.
      PeriodMode.week => RecordPeriod(
          mode,
          DateTime(day.year, day.month, day.day - (day.weekday - 1)),
        ),
      PeriodMode.month => RecordPeriod(mode, DateTime(day.year, day.month, 1)),
    };
  }

  /// 다음 구간의 첫 자정. 이 구간에 **포함되지 않는** 경계입니다.
  DateTime get end => switch (mode) {
        PeriodMode.day => DateTime(start.year, start.month, start.day + 1),
        PeriodMode.week => DateTime(start.year, start.month, start.day + 7),
        PeriodMode.month => DateTime(start.year, start.month + 1, 1),
      };

  RecordPeriod get previous => switch (mode) {
        PeriodMode.day =>
          RecordPeriod(mode, DateTime(start.year, start.month, start.day - 1)),
        PeriodMode.week =>
          RecordPeriod(mode, DateTime(start.year, start.month, start.day - 7)),
        PeriodMode.month =>
          RecordPeriod(mode, DateTime(start.year, start.month - 1, 1)),
      };

  RecordPeriod get next => RecordPeriod(mode, end);

  /// 구간에 든 모든 날의 자정. 하루면 1개, 주면 7개, 달이면 28~31개입니다.
  List<DateTime> get days {
    final result = <DateTime>[];
    for (var day = start; day.isBefore(end);) {
      result.add(day);
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  /// 구간 마지막 날의 자정.
  DateTime get lastDay {
    final all = days;
    return all.last;
  }

  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);

  /// [now]가 든 구간인지.
  bool isCurrent(DateTime now) => contains(now);

  /// [now]보다 **완전히 앞선** 구간인지. 앞으로 넘어가지 못하게 막는 데 씁니다.
  ///
  /// [isCurrent]만으로 막으면 지금 구간만 걸리고 아직 오지 않은 구간은
  /// 지나갑니다. 주 스트립이나 달 달력에서 앞날을 누른 뒤 눈금을 좁히면
  /// 구간 전체가 앞날이 되는데, 그때부터는 끝없이 앞으로 갈 수 있습니다.
  bool hasEnded(DateTime now) => !end.isAfter(now);

  /// 머리글에 적히는 이름.
  String get label {
    switch (mode) {
      case PeriodMode.day:
        final weekday = weekdayLabel(start);
        return '${start.month}월 ${start.day}일 ($weekday)';
      case PeriodMode.week:
        final last = lastDay;
        if (last.month == start.month) {
          return '${start.month}월 ${start.day}일 ~ ${last.day}일';
        }
        return '${start.month}월 ${start.day}일 ~ ${last.month}월 ${last.day}일';
      case PeriodMode.month:
        return '${start.year}년 ${start.month}월';
    }
  }

  /// 눈금만 바꾸고 **보던 날은 그대로** 둡니다.
  ///
  /// 주에서 달로 옮길 때 무조건 오늘로 튀면, 지난달을 살펴보다 눈금을 바꾼
  /// 사람이 매번 이번 달로 끌려옵니다.
  RecordPeriod withMode(PeriodMode next, DateTime selectedDay) =>
      RecordPeriod.of(next, selectedDay);

  @override
  bool operator ==(Object other) =>
      other is RecordPeriod && other.mode == mode && other.start == start;

  @override
  int get hashCode => Object.hash(mode, start);
}

/// '월'~'일'. 달력 머리글과 하루 이름에 씁니다.
String weekdayLabel(DateTime day) =>
    const ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1];

/// 원 위에 그리는 수면 한 조각. 시각은 **그 날 안에서의 시(hour)**입니다.
///
/// 자정을 넘는 잠은 두 조각이 됩니다: 월요일 20.0~24.0, 화요일 0.0~6.0.
class SleepArc {
  /// 0.0 이상 24.0 미만.
  final double startHour;

  /// [startHour]보다 크고 24.0 이하.
  final double endHour;

  /// 아직 끝나지 않은 수면의 마지막 조각인지. 끝을 모르므로 지금까지만
  /// 그렸다는 뜻입니다.
  final bool ongoing;

  const SleepArc({
    required this.startHour,
    required this.endHour,
    this.ongoing = false,
  });

  double get hours => endHour - startHour;
}

/// 원 둘레에 찍는 점의 종류.
enum DotKind { feeding, diaper }

/// 원 둘레의 점 하나.
class DayDot {
  final DotKind kind;

  /// 0.0 이상 24.0 미만.
  final double hour;

  const DayDot({required this.kind, required this.hour});
}

/// 하루치 원 하나의 내용.
class DayPattern {
  /// 그 날의 자정.
  final DateTime day;

  final List<SleepArc> sleepArcs;
  final List<DayDot> dots;

  /// **이 원에 그려진** 수면의 합. 자정을 넘는 잠은 양쪽 날에 나뉘어 들어가므로
  /// 한 잠의 전체 길이가 아닙니다.
  final Duration sleepTotal;

  final int feedingCount;
  final int diaperCount;

  const DayPattern({
    required this.day,
    required this.sleepArcs,
    required this.dots,
    required this.sleepTotal,
    required this.feedingCount,
    required this.diaperCount,
  });

  /// 원에 그릴 것이 하나도 없는지. 체온·약처럼 원에 안 그리는 기록만 있는
  /// 날도 여기서는 비어 있다고 봅니다 — 원 이야기이기 때문입니다.
  bool get isEmpty => sleepArcs.isEmpty && dots.isEmpty;

  /// 아직 끝나지 않은 수면이 이 날에 걸쳐 있는지.
  bool get hasOngoingSleep => sleepArcs.any((a) => a.ongoing);
}

/// 끝나지 않은 수면을 그려 주는 한도.
///
/// 이보다 오래 열려 있으면 재는 중인 잠이 아니라 **끝맺지 못한 기록**으로
/// 봅니다. 언제 끝났는지 모르므로 그리지 않습니다.
const Duration _openSleepLimit = Duration(hours: 24);

/// 시각을 그 날 안에서의 시로 옮깁니다. 14:30 → 14.5.
///
/// 뺄셈을 하지 않습니다. `difference(자정)`으로 재면 서머타임이 시작한 날에는
/// 한 시간이 통째로 어긋납니다.
double hourOfDay(DateTime at) =>
    at.hour + at.minute / 60 + at.second / 3600;

/// 한 구간의 기록을 날짜별 원으로 나눕니다. 첫날부터 차례로 돌려줍니다.
///
/// [now]는 아직 끝나지 않은 수면을 어디까지 그릴지 정합니다. 이것 없이
/// `DateTime.now()`를 안에서 부르면 테스트가 시각에 따라 흔들립니다.
///
/// 기록이 없는 날은 빈 [DayPattern]입니다. 채워 넣거나 평균을 내지 않습니다.
List<DayPattern> buildDayPatterns({
  required RecordPeriod period,
  List<FeedingRecord> feedings = const [],
  List<DiaperRecord> diapers = const [],
  List<SleepRecord> sleeps = const [],
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final periodDays = period.days;

  /// 달력 날짜 자체를 키로 씁니다(20260818). 어떤 뺄셈도 하지 않으므로
  /// 시간대·서머타임과 무관합니다.
  int dayKey(DateTime at) => at.year * 10000 + at.month * 100 + at.day;

  final arcs = <int, List<SleepArc>>{};
  final dots = <int, List<DayDot>>{};
  for (final day in periodDays) {
    arcs[dayKey(day)] = [];
    dots[dayKey(day)] = [];
  }

  void addDot(DateTime at, DotKind kind) {
    if (!period.contains(at)) return;
    dots[dayKey(at)]!.add(DayDot(kind: kind, hour: hourOfDay(at)));
  }

  for (final r in feedings) {
    addDot(r.fedAt, DotKind.feeding);
  }
  for (final r in diapers) {
    addDot(r.recordedAt, DotKind.diaper);
  }

  for (final s in sleeps) {
    // 끝나지 않은 수면은 지금까지만 그립니다. 시작이 미래면 그릴 것이 없습니다.
    final rawEnd = s.endedAt ?? reference;
    final ongoing = s.endedAt == null;

    // **하루가 넘도록 끝나지 않은 것은 그리지 않습니다.**
    //
    // 소음 측정을 켜 두고 끝맺지 못한 행이 실제로 생깁니다. 그것을 '지금까지
    // 자는 중'으로 보고 그리면 한 건이 여러 날을 24시간 수면으로 채웁니다
    // (9월 1일 21시에 열린 행 하나가 18일을 꽉 채웠습니다). 아이가 그렇게
    // 잤다는 근거는 어디에도 없으니 지어내는 쪽입니다.
    //
    // `weekly_summary.dart`가 이미 같은 판단을 합니다 — "끝난 수면만
    // 더합니다. 측정 중인 수면은 길이를 알 수 없습니다."
    //
    // 오늘 밤 재는 중인 잠은 하루를 넘지 않으므로 그대로 그려집니다.
    if (ongoing && rawEnd.difference(s.startedAt) > _openSleepLimit) continue;

    // 이 구간 밖으로 삐져나간 부분은 자릅니다. 전날 밤에 시작해 첫날 새벽에
    // 끝난 잠이 **첫날 원의 0~6시**로 남는 것이 이 자르기입니다.
    final from = s.startedAt.isBefore(period.start) ? period.start : s.startedAt;
    final to = rawEnd.isAfter(period.end) ? period.end : rawEnd;

    // 0길이·역전(끝이 시작보다 이름)은 그리지 않습니다. DB 제약이 막고 있지만
    // 측정 중인 행은 끝이 없어 여기서 처음 걸립니다.
    if (!to.isAfter(from)) continue;

    var cursor = from;
    // 구간으로 잘랐으므로 조각은 많아야 날 수만큼입니다. 이상한 데이터가
    // 무한히 돌지 않게 경계로도 둡니다.
    final maxSlices = periodDays.length + 1;
    for (var guard = 0; guard < maxSlices && cursor.isBefore(to); guard++) {
      final midnight = DateTime(cursor.year, cursor.month, cursor.day);
      final nextMidnight =
          DateTime(cursor.year, cursor.month, cursor.day + 1);
      final sliceEnd = to.isBefore(nextMidnight) ? to : nextMidnight;

      final startHour = hourOfDay(cursor);
      // 자정에서 끊긴 조각의 끝은 24시입니다. hourOfDay를 쓰면 0.0이 되어
      // 길이가 음수인 호가 됩니다.
      final endHour = sliceEnd == nextMidnight ? 24.0 : hourOfDay(sliceEnd);

      // 정확히 자정에 끝난 잠이 다음 날에 길이 0인 호를 만들지 않게 합니다.
      if (endHour > startHour) {
        arcs[dayKey(midnight)]?.add(SleepArc(
          startHour: startHour,
          endHour: endHour,
          // 마지막 조각만 '측정 중'입니다.
          ongoing: ongoing && sliceEnd == to,
        ));
      }

      cursor = sliceEnd;
    }
  }

  return [
    for (final day in periodDays)
      _patternFor(day, arcs[dayKey(day)]!, dots[dayKey(day)]!),
  ];
}

DayPattern _patternFor(
  DateTime day,
  List<SleepArc> arcs,
  List<DayDot> dots,
) {
  var minutes = 0;
  for (final a in arcs) {
    minutes += (a.hours * 60).round();
  }

  arcs.sort((a, b) => a.startHour.compareTo(b.startHour));
  dots.sort((a, b) => a.hour.compareTo(b.hour));

  return DayPattern(
    day: day,
    sleepArcs: arcs,
    dots: dots,
    sleepTotal: Duration(minutes: minutes),
    feedingCount: dots.where((d) => d.kind == DotKind.feeding).length,
    diaperCount: dots.where((d) => d.kind == DotKind.diaper).length,
  );
}
