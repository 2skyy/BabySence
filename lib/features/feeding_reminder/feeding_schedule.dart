import '../../core/services/baby_service.dart' show trimmedBabyName;

/// 다음 수유 예정 시각.
///
/// 마지막 수유 기록에 **보호자가 정한 간격**을 더한 값입니다. 앱이 간격을
/// 추측하지 않습니다 — 아이마다 다르고, 앱이 정할 근거가 없습니다. 간격을
/// 정하기 전에는 다음 시각을 보여주지 않습니다([nextAt]이 null).
///
/// 이것은 판정이 아닙니다. "이때 먹여야 한다"가 아니라 "보호자가 정한 간격이
/// 지났다"만 말합니다.
class FeedingSchedule {
  /// 마지막 수유 시각. 기록이 없으면 null입니다.
  final DateTime? lastFedAt;

  /// 보호자가 정한 간격. 아직 정하지 않았으면 null입니다.
  final Duration? interval;

  const FeedingSchedule({this.lastFedAt, this.interval});

  /// 다음 수유 예정 시각. 마지막 기록과 간격이 모두 있어야 정해집니다.
  DateTime? get nextAt {
    final last = lastFedAt;
    final gap = interval;
    if (last == null || gap == null) return null;
    return last.add(gap);
  }

  /// [now]에서 다음 시각까지 남은 시간. 이미 지났으면 음수입니다.
  Duration? remainingAt(DateTime now) => nextAt?.difference(now);

  /// 정한 간격이 이미 지났는지.
  bool isOverdueAt(DateTime now) {
    final left = remainingAt(now);
    return left != null && left.isNegative;
  }
}

/// 간격을 처음 정할 때 보여줄 값.
///
/// **권장 간격이 아닙니다.** 공인 지침에서 개월 수별 수유 간격을 숫자로
/// 정해 둔 것을 찾지 못했습니다. 빈 칸에서 시작하면 고르기 어려우니 흔히
/// 쓰는 값을 미리 넣어 둘 뿐이고, 보호자가 바꾸는 것을 전제로 합니다.
Duration suggestedInterval(int ageInMonths) {
  if (ageInMonths < 4) return const Duration(hours: 3);
  if (ageInMonths < 7) return const Duration(hours: 4);
  return const Duration(hours: 5);
}

/// 고를 수 있는 간격. 30분 단위로 1시간부터 6시간까지.
List<Duration> get selectableIntervals => [
      for (var minutes = 60; minutes <= 360; minutes += 30)
        Duration(minutes: minutes),
    ];

/// '3시간', '3시간 30분'처럼 읽습니다.
String formatInterval(Duration interval) {
  final hours = interval.inHours;
  final minutes = interval.inMinutes % 60;
  if (minutes == 0) return '$hours시간';
  if (hours == 0) return '$minutes분';
  return '$hours시간 $minutes분';
}

/// 남은 시간을 사람이 읽는 말로.
///
/// 지난 경우를 "-1시간"으로 두면 읽는 사람이 한 번 더 생각해야 합니다.
String formatRemaining(Duration remaining) {
  if (remaining.inMinutes.abs() < 1) return '지금이에요';

  final passed = remaining.isNegative;
  final gap = remaining.abs();
  final hours = gap.inHours;
  final minutes = gap.inMinutes % 60;

  final amount = hours == 0
      ? '$minutes분'
      : minutes == 0
          ? '$hours시간'
          : '$hours시간 $minutes분';

  return passed ? '$amount 지났어요' : '$amount 뒤';
}

/// '오후 2:30'.
String formatClock(DateTime at) {
  final period = at.hour < 12 ? '오전' : '오후';
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '$period $hour:${at.minute.toString().padLeft(2, '0')}';
}

/// 수유 알림 제목. 이름을 알면 부릅니다.
///
/// 알림창에는 앱 이름이 이미 붙지만 아이 이름은 없습니다. 함께 키우는 두
/// 사람이 각자 기기에서 받으므로, 누구 이야기인지가 제목에 있어야 합니다.
String feedingNotificationTitle(String? babyName) {
  final name = trimmedBabyName(babyName);
  return name == null ? '수유 시간이 되었어요' : '$name 수유 시간이 되었어요';
}

/// 수유 알림 본문. **왜 지금 울리는지**를 적습니다.
///
/// 예전에는 '오후 2:10로 정하신 시간이 되었어요.'였습니다. 두 가지가
/// 어긋났습니다 — 적힌 시각이 다음 예정 시각이라 마지막으로 먹인 때와
/// 헷갈렸고, 조사가 앞 숫자를 읽는 방식에 따라 '로'와 '으로'로 갈리는데
/// 늘 '로'였습니다('2:10로'). 조사가 필요 없는 문장으로 바꿉니다.
String feedingNotificationBody({
  required DateTime lastFedAt,
  required Duration interval,
}) =>
    '마지막 수유 ${formatClock(lastFedAt)} · ${formatInterval(interval)} 간격';
