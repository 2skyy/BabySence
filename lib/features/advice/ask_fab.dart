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
              // 앱 안에서 상담으로 가는 **유일한 입구**입니다. 각 기록
              // 화면의 아이콘을 모두 없앴으므로, 이 대화가 체온·수유·배변·
              // 수면·약병원 기록을 전부 맥락으로 받습니다
              // (ChatContext의 _everything).
              builder: (_) => const ChatPage(domain: AssessmentDomain.overall),
            ),
          ),
          // **원으로 잘라 냅니다.**
          //
          // 아이콘은 자체 배경을 가진 정사각형 이미지입니다. 원 안에
          // 그냥 얹으면 네 모서리가 드러나 '원 안의 네모'로 보입니다.
          // 여백을 두고 줄이면 60px 안에서 선이 1px 남짓이 되어 뭉갭니다.
          //
          // 잘라서 꽉 채우면 아이콘 자체가 곧 동그란 단추가 됩니다.
          //
          // 앱 아이콘(app_icon.png)이 아니라 배경을 어둡게 내린 판을
          // 씁니다. 원본은 밝은 민트 배경이라 **흰 선과 대비가 1.35:1**로
          // 선이 보이지 않았고, 홈의 다른 강조색(AppColors.primary)과도
          // 따로 놀았습니다. 만드는 법은 tool/make_chat_logo.py에 있습니다.
          child: ClipOval(
            child: SizedBox(
              width: 60,
              height: 60,
              child: Image.asset(
                'assets/icon/chat_logo.png',
                fit: BoxFit.cover,
                // 이미지를 못 읽어도 단추는 살아 있어야 합니다.
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
