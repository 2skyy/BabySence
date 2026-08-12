import 'package:flutter/material.dart';

import '../advice/ask_button.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/medical_disclaimer.dart';
import 'assessment/assessment.dart';

/// 수면 소음 측정 결과.
///
/// 예전에는 이 화면이 근거 없는 50/70dB로 직접 문구를 만들었습니다. 지금은
/// [NoiseRules]가 낸 판정을 받아 보여주기만 합니다 — 임계값이 코드 한 곳에만
/// 있어야 논문의 기준과 어긋나지 않습니다.
class NoiseResultPage extends StatelessWidget {
  final Assessment assessment;

  const NoiseResultPage({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    final color = switch (assessment.level) {
      AssessmentLevel.normal => AppColors.primary,
      AssessmentLevel.caution => Colors.orange.shade700,
      AssessmentLevel.consult => AppColors.error,
    };

    final icon = switch (assessment.level) {
      AssessmentLevel.normal => Icons.check_circle,
      AssessmentLevel.caution => Icons.warning_amber_rounded,
      AssessmentLevel.consult => Icons.volume_up,
    };

    final average = assessment.inputs['average_db'] as num?;
    final max = assessment.inputs['max_db'] as num?;
    final samples = assessment.inputs['sample_count'] as num?;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const CommonAppBar(title: '수면 소음 결과'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: AppSpacing.md),
                Text(
                  // 소음은 '상담 권장' 대신 '개선 권장'으로 부릅니다.
                  assessment.levelLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (average != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '평균 ${average.toStringAsFixed(1)}dB',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              assessment.guideText,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildBasis(context, average, max, samples),
          const SizedBox(height: AppSpacing.lg),
          AskButton(
            domain: AssessmentDomain.noise,
            assessment: assessment,
            label: '이 결과에 대해 물어보기',
          ),
          const SizedBox(height: AppSpacing.lg),
          const MedicalDisclaimer(),
        ],
      ),
    );
  }

  /// 판정 근거를 그대로 보여줍니다.
  ///
  /// 무슨 값으로 어떤 기준을 적용했는지 사용자가 확인할 수 있어야
  /// "근거를 추적 가능한 형태로 제시한다"는 설계가 화면에서도 성립합니다.
  Widget _buildBasis(BuildContext context, num? average, num? max, num? samples) {
    final rows = <(String, String)>[
      if (average != null) ('평균 소음', '${average.toStringAsFixed(1)} dB'),
      if (max != null) ('최대 소음', '${max.toStringAsFixed(1)} dB'),
      if (samples != null) ('측정 표본', '${samples.toInt()}건'),
      ('적용 기준', '30dB 미만 정상 · 50dB 초과 개선 권장'),
      ('기준 버전', assessment.ruleVersion),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '판정 근거',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          // 이 한계를 숨기면 측정값이 절대 기준을 충족한다고 오해합니다.
          Text(
            '※ 마이크 보정값이 실제 소음계와 대조되지 않아, 절대 수치의 '
            '정확도는 확인되지 않았습니다.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
