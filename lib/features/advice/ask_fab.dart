import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../detail/assessment/assessment.dart';
import 'chat_page.dart';

/// 홈 오른쪽 아래에 떠 있는 상담 단추.
///
/// ## 왜 여기로 왔나
///
/// 처음에는 각 기록 화면 한가운데에 '~에 대해 물어보기' 전면 버튼이
/// 있었습니다. 늘 떠 있어 기록하러 들어온 사람의 눈길을 계속 끌었습니다.
/// 그래서 앱바 오른쪽의 작은 말풍선 아이콘으로 옮겼는데, 이번에는 **아무도
/// 못 찾는** 문제가 생겼습니다. 있는지조차 몰랐습니다.
///
/// 두 실패의 공통점은 자리를 **기록 화면 안에서** 찾으려 한 것입니다.
/// 기록하는 중에 눈에 띄면 방해가 되고, 방해가 안 되면 안 보입니다.
///
/// 그래서 자리를 옮겼습니다. 홈은 **기록하러 들어가기 전에 머무는 곳**이라,
/// 여기서는 눈에 띄어도 하던 일을 가로막지 않습니다.
///
/// ## 가리지 않게 하는 것
///
/// 떠 있는 단추는 스크롤한 내용의 마지막 줄을 덮습니다. 홈 목록 아래쪽에
/// [reservedHeight]만큼 여백을 두어야 마지막 카드가 가려지지 않습니다.
class AskFab extends StatelessWidget {
  const AskFab({super.key});

  /// 홈 목록이 아래에 비워 둬야 하는 높이.
  ///
  /// 단추 지름(60) + 아래 여백(16) + 손가락이 닿을 여유(12).
  static const double reservedHeight = 88;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '아이에 대해 물어보기',
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              // 홈에서 여는 대화라 영역이 정해져 있지 않습니다. 아이의 최근
              // 기록 전체를 맥락으로 받는 '종합'으로 엽니다.
              builder: (_) => const ChatPage(domain: AssessmentDomain.overall),
            ),
          ),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Padding(
              // 아이콘 원본에 여백이 거의 없어 원 안에 꽉 찹니다.
              padding: const EdgeInsets.all(11),
              child: Image.asset(
                'assets/icon/app_icon.png',
                // 이미지를 못 읽어도 단추는 살아 있어야 합니다.
                errorBuilder: (_, _, _) => const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
