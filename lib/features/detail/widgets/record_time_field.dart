import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import 'now_time_button.dart';

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

/// 라벨 + '지금' 버튼 + 오전/오후 · 시:분 입력.
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _periodButton(context, '오전'),
              const SizedBox(width: 6),
              _periodButton(context, '오후'),
              const SizedBox(width: 10),
              _numberField(context, controller.hour, max: 12, min: 1),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              _numberField(context, controller.minute, max: 59, min: 0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodButton(BuildContext context, String value) {
    final selected = controller.period == value;
    return GestureDetector(
      onTap: () {
        controller.period = value;
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    BuildContext context,
    TextEditingController field, {
    required int max,
    required int min,
  }) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: field,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        // 범위를 벗어나면 그 자리에서 되돌립니다. 저장할 때 알려주면
        // 무엇이 잘못됐는지 찾아 올라가야 합니다.
        onChanged: (value) {
          if (value.isEmpty) return;
          final parsed = int.tryParse(value);
          if (parsed == null) return;
          if (parsed < min) {
            field.text = '$min';
          } else if (parsed > max) {
            field.text = '$max';
          }
          field.selection = TextSelection.fromPosition(
            TextPosition(offset: field.text.length),
          );
          onChanged();
        },
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
