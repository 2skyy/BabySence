import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// 오전/오후 + 시:분 입력칸에 넣을 값.
///
/// 배변·수면 화면이 같은 모양의 입력을 쓰므로 한 곳에서 만듭니다.
typedef TimeFields = ({String period, String hour, String minute});

/// [at](기본값은 현재 시각)을 화면 입력칸 형식으로 바꿉니다.
///
/// 시각은 12시간제로 씁니다. 0시는 오전 12시, 13시는 오후 1시입니다.
/// 두 자리로 채워 `08:05`처럼 보이게 합니다 — 한 자리로 두면 숫자 폭이
/// 달라져 입력칸이 흔들립니다.
TimeFields nowTimeFields([DateTime? at]) {
  final t = at ?? DateTime.now();
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;

  return (
    period: t.hour < 12 ? '오전' : '오후',
    hour: hour12.toString().padLeft(2, '0'),
    minute: t.minute.toString().padLeft(2, '0'),
  );
}

/// 지금 시각을 한 번에 채워 넣는 버튼.
///
/// 기록은 대개 일이 벌어진 직후에 남깁니다. 그때마다 오전/오후를 고르고
/// 시와 분을 따로 입력하게 하면 손이 많이 갑니다.
class NowTimeButton extends StatelessWidget {
  /// 눌렀을 때 입력칸을 [nowTimeFields]로 채우는 쪽에서 처리합니다.
  final VoidCallback onPressed;

  /// 여러 개일 때 무엇을 채우는지 구분합니다(예: '취침', '기상').
  final String? semanticLabel;

  const NowTimeButton({
    super.key,
    required this.onPressed,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel == null ? '지금' : '$semanticLabel을 지금으로';

    return Tooltip(
      message: label,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.schedule, size: 16),
        label: const Text('지금'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
