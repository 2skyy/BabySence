import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// 눌러서 시각을 고르는 칸.
///
/// 예전에는 오전/오후 칩 하나와 시·분 입력칸 두 개를 각각 눌러 고쳐야 했습니다.
/// 기록 하나 남기는 데 숫자를 두 번 타이핑해야 했고, 키보드가 올라오면서
/// 화면이 밀렸습니다. 지금은 한 번 눌러 시스템 시간 선택기를 엽니다.
///
/// 글자 크기를 키워도 넘치지 않습니다. 한 줄짜리 [Text] 하나라
/// 좁은 폭에서 겹칠 것이 없습니다.
class TimePickerBox extends StatelessWidget {
  /// 지금 고른 시각. null이면 아직 고르지 않은 상태입니다.
  final TimeOfDay? value;

  final ValueChanged<TimeOfDay> onChanged;

  /// 선택기 위에 뜨는 안내. 시작/종료처럼 둘을 구분할 때 씁니다.
  final String? helpText;

  const TimePickerBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.helpText,
  });

  /// '오후 3:24'. 시스템 형식을 쓰지 않는 이유는 나머지 화면이 모두
  /// 이 표기를 쓰고 있어서입니다.
  static String format(TimeOfDay time) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$period $hour12:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? TimeOfDay.now(),
      helpText: helpText,
      // 손으로 적는 쪽이 기본입니다. 몇 시 몇 분인지 이미 알고 여는
      // 화면이라, 다이얼을 돌리는 것보다 빠릅니다.
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final time = value;

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 20, color: context.colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  time == null ? '시간을 고르세요' : format(time),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: time == null
                        ? context.colors.textSecondary
                        : context.colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 20, color: context.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
