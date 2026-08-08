/// 수면 종류. enum 이름이 sleep_records.sleep_type의 CHECK 제약
/// (`night` / `nap`)과 그대로 일치해야 합니다.
///
/// 소음 측정과 수면 기록 화면이 함께 쓰므로 따로 두었습니다.
enum SleepType {
  night('밤잠'),
  nap('낮잠');

  const SleepType(this.label);

  /// 화면에 표시할 이름.
  final String label;

  /// service.invoke로 넘어온 문자열을 되돌립니다. 알 수 없는 값은 밤잠으로 봅니다.
  static SleepType parse(String? raw) => SleepType.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => SleepType.night,
      );
}
