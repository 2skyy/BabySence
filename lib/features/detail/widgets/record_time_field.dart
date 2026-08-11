import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'now_time_button.dart';
import 'time_picker_box.dart';

/// 오전/오후 + 시:분 입력칸들의 상태.
///
/// 수유·배변·체온이 같은 입력을 쓰므로 한 곳에 모았습니다. 화면마다
/// 컨트롤러 세 개를 따로 들고 다니면 초기화와 dispose를 빠뜨리기 쉽습니다.
class RecordTimeController {
  String period;
  final TextEditingController hour;
  final TextEditingController minute;

  RecordTimeController._(this.period, this.hour, this.minute);

  /// 지금 시각으로 시작합니다. 기록은 대개 일이 벌어진 직후에 남깁니다.
  factory RecordTimeController.now([DateTime? at]) {
    final t = nowTimeFields(at);
    return RecordTimeController._(
      t.period,
      TextEditingController(text: t.hour),
      TextEditingController(text: t.minute),
    );
  }

  /// 입력칸을 지금 시각으로 되돌립니다.
  void setNow([DateTime? at]) {
    final t = nowTimeFields(at);
    period = t.period;
    hour.text = t.hour;
    minute.text = t.minute;
  }

  /// 지금 들어 있는 시각. 형식이 틀리면 null입니다.
  ///
  /// 저장할 값은 [toDateTime]이 만듭니다. 이 값은 화면에 보여 주고
  /// 시간 선택기를 열 때의 시작점으로만 씁니다.
  TimeOfDay? get timeOfDay {
    final h = int.tryParse(hour.text);
    final m = int.tryParse(minute.text);
    if (h == null || m == null) return null;
    if (h < 1 || h > 12 || m < 0 || m > 59) return null;

    var hour24 = h % 12;
    if (period == '오후') hour24 += 12;
    return TimeOfDay(hour: hour24, minute: m);
  }

  /// 시간 선택기에서 고른 값을 입력칸에 넣습니다.
  void setTimeOfDay(TimeOfDay time) {
    period = time.hour < 12 ? '오전' : '오후';
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    hour.text = hour12.toString().padLeft(2, '0');
    minute.text = time.minute.toString().padLeft(2, '0');
  }

  /// 입력값을 실제 시각으로 만듭니다. 형식이 틀리면 null입니다.
  ///
  /// 날짜는 오늘로 잡되, 미래가 되면 어제로 봅니다 — 자정 직후에 전날 일을
  /// 기록하는 경우가 있습니다(예: 0시 10분에 '오후 11시 30분' 입력).
  DateTime? toDateTime([DateTime? now]) {
    final h = int.tryParse(hour.text);
    final m = int.tryParse(minute.text);
    if (h == null || m == null) return null;
    if (h < 1 || h > 12 || m < 0 || m > 59) return null;

    var hour24 = h % 12;
    if (period == '오후') hour24 += 12;

    final reference = now ?? DateTime.now();
    final at = DateTime(
      reference.year,
      reference.month,
      reference.day,
      hour24,
      m,
    );
    return at.isAfter(reference) ? at.subtract(const Duration(days: 1)) : at;
  }

  void dispose() {
    hour.dispose();
    minute.dispose();
  }
}

/// 라벨 + '지금' 버튼 + 눌러서 고르는 시각.
///
/// 기본값은 화면을 연 시각이고, 필요하면 직접 고칠 수 있습니다.
class RecordTimeField extends StatelessWidget {
  final String label;
  final RecordTimeController controller;

  /// 입력이 바뀌었음을 화면에 알립니다(setState 호출용).
  final VoidCallback onChanged;

  const RecordTimeField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            NowTimeButton(onPressed: () {
              controller.setNow();
              onChanged();
            }),
          ],
        ),
        const SizedBox(height: 14),
        TimePickerBox(
          value: controller.timeOfDay,
          helpText: label,
          onChanged: (picked) {
            controller.setTimeOfDay(picked);
            onChanged();
          },
        ),
      ],
    );
  }


}
