import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

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
///
/// ## 내려 읽는 동안에는 비킵니다
///
/// [controller]를 주면 아래로 내려 읽는 동안 숨고, **손가락을 아래로 끌면**
/// 다시 나타납니다. 맨 위에서는 항상 보입니다.
///
/// 완전히 숨기지 않는 이유는 위에 적은 두 번째 실패 때문입니다 — 앱바
/// 아이콘으로 옮겼을 때 아무도 못 찾았습니다. 홈에 들어오면 처음부터 보이고
/// 위로 올리면 곧바로 돌아오므로, '있는지조차 모르는' 자리로는 가지
/// 않습니다.
class AskFab extends StatefulWidget {
  /// 홈 목록의 스크롤. 없으면 **늘 보입니다**(기록 화면·테스트).
  final ScrollController? controller;

  const AskFab({super.key, this.controller});

  /// 홈 목록이 아래에 비워 둬야 하는 높이.
  ///
  /// 단추 지름(60) + 아래 여백(16) + 손가락이 닿을 여유(12).
  ///
  /// **숨어 있을 때도 그대로 비워 둡니다.** 스크롤 도중에 목록 높이가
  /// 바뀌면 보던 자리가 튀고, 단추가 돌아올 때 마지막 카드를 덮습니다.
  static const double reservedHeight = 88;

  @override
  State<AskFab> createState() => _AskFabState();
}

class _AskFabState extends State<AskFab> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(AskFab old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onScroll);
      widget.controller?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.controller;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;

    // 맨 위에서는 항상 보입니다. 홈에 들어온 첫 화면이 여기이고, 탭을
    // 다시 눌러 맨 위로 돌아오는 경로도 여기로 들어옵니다.
    //
    // 스크롤할 것이 없는 경우(기록이 적어 홈이 한 화면에 들어오는 사람)는
    // 따로 막지 않습니다 — 그때는 이 리스너가 **한 번도 불리지 않습니다.**
    // 돌려서 확인했습니다(바운스·클램핑 두 물리 모두 알림 0건).
    if (position.pixels <= 0) return _setVisible(true);

    switch (position.userScrollDirection) {
      case ScrollDirection.reverse: // 내려 읽는 중
        _setVisible(false);
      case ScrollDirection.forward: // 손가락을 아래로 끄는 중
        _setVisible(true);
      case ScrollDirection.idle:
        break; // 손을 뗀 뒤에는 그대로 둡니다.
    }
  }

  void _setVisible(bool value) {
    if (_visible == value || !mounted) return;
    setState(() => _visible = value);
  }

  @override
  Widget build(BuildContext context) {
    // 숨었을 때는 눌리지도, 낭독되지도 않아야 합니다. 보이지 않는 단추가
    // 손가락을 먹으면 그 자리의 카드를 누를 수 없습니다.
    return IgnorePointer(
      ignoring: !_visible,
      child: ExcludeSemantics(
        excluding: !_visible,
        child: AnimatedScale(
          scale: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: _button(context),
        ),
      ),
    );
  }

  Widget _button(BuildContext context) {
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
