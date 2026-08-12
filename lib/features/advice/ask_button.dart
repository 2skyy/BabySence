import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../detail/assessment/assessment.dart';
import 'chat_page.dart';

/// 기록 화면에서 그 영역의 상담으로 넘어가는 버튼.
///
/// 상담을 따로 모아 둔 탭이 아니라 **기록하던 자리**에 둡니다. 체온을 재다
/// 궁금해진 것은 체온에 대한 것이고, 그때 화면을 옮겨 다시 영역을 고르게
/// 하면 묻기를 그만두게 됩니다.
class AskButton extends StatelessWidget {
  final AssessmentDomain domain;

  /// 방금 나온 판정. 있으면 대화의 출발점이 됩니다.
  final Assessment? assessment;

  /// 버튼에 적을 말. 판정 바로 아래에 둘 때는 "이 결과에 대해 물어보기"처럼
  /// 무엇을 묻는지 분명히 하는 편이 낫습니다.
  final String? label;

  const AskButton({
    super.key,
    required this.domain,
    this.assessment,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(domain: domain, assessment: assessment),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: context.colors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: Text(
          label ?? '${domain.label}에 대해 물어보기',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
