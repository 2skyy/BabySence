/// 시간을 사람이 읽는 말로 옮깁니다.
///
/// **한 곳에 둡니다.** 같은 잠을 화면마다 다르게 부르면 안 됩니다. 예전에는
/// 세 자리가 각자 적어, 50분짜리 낮잠을 원 카드는 '50분'이라 하고 목록과
/// 홈 타일은 `'${d.inHours}시간 ${d.inMinutes % 60}분'`으로 만들어
/// **'0시간 50분'**이라 불렀습니다.
library;

/// '7시간 30분'처럼 읽습니다. 0분이면 시간만, 한 시간이 안 되면 분만 씁니다.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}
