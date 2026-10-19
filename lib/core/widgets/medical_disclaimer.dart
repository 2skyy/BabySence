import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// 이 앱이 의료기기가 아니라는 상시 고지.
///
/// 판정("정상 / 주의 / 상담 권장")이나 AI가 만든 문장을 보여주는 자리에는
/// 반드시 함께 둡니다. 판정만 보여주고 이 문구가 없으면, 사용자가 진단으로
/// 받아들일 수 있습니다.
///
/// 문구를 한 곳에서만 관리하는 이유는 화면마다 표현이 갈리면 어느 것이
/// 공식 안내인지 알 수 없게 되기 때문입니다.
class MedicalDisclaimer extends StatelessWidget {
  /// 눈에 띄어야 하는 자리(판정 결과, AI 답변)에는 카드로,
  /// 화면 아래 상시 표시에는 한 줄로 씁니다.
  final bool compact;

  const MedicalDisclaimer({super.key, this.compact = false});

  /// 짧은 형태. 화면 하단에 상시 두는 용도입니다.
  static const String shortText =
      '이 앱은 의료기기가 아니며, 안내는 참고용입니다.';

  /// 판정·AI 답변 옆에 붙이는 형태.
  static const String fullText =
      '이 앱은 의료기기가 아닙니다. 여기서 보여드리는 판정과 안내는 '
      '공개된 기준을 바탕으로 한 참고 정보이며, 의사의 진단을 대신하지 않습니다. '
      '아이 상태가 걱정되면 소아과 진료를 받아 주세요.';

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Text(
        shortText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: context.colors.textSecondary,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              fullText,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
