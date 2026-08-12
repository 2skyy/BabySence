import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../detail/assessment/assessment.dart';
import 'chat_page.dart';

/// 기록 화면 앱바 오른쪽에서 그 영역의 상담을 여는 아이콘.
///
/// 상담을 따로 모아 둔 탭이 아니라 **기록하던 자리**에 둡니다. 체온을 재다
/// 궁금해진 것은 체온에 대한 것이고, 그때 화면을 옮겨 다시 영역을 고르게
/// 하면 묻기를 그만두게 됩니다.
///
/// 예전에는 화면 한가운데 전면 버튼으로 두었습니다. 늘 떠 있으니 기록하러
/// 들어온 사람의 눈길을 계속 끌었습니다. 필요할 때 찾아 누르는 것으로
/// 충분해서 앱바로 옮겼습니다 — 자리는 화면마다 같고, 기록을 가리지
/// 않습니다.
class AskAction extends StatelessWidget {
  final AssessmentDomain domain;

  /// 방금 나온 판정. 있으면 대화의 출발점이 됩니다.
  final Assessment? assessment;

  /// 길게 눌렀을 때 뜨는 말. 아이콘만으로는 무엇인지 모르므로 비워 두지
  /// 않습니다. 영역 이름이 그대로 맞지 않는 화면만 직접 줍니다.
  final String? tooltip;

  const AskAction({
    super.key,
    required this.domain,
    this.assessment,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.chat_bubble_outline, size: 21),
      color: AppColors.primary,
      tooltip: tooltip ?? '${domain.label}에 대해 물어보기',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(domain: domain, assessment: assessment),
        ),
      ),
    );
  }
}
