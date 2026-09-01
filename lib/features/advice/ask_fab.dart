import 'package:flutter/foundation.dart' show ValueListenable;
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
/// ## 평소에는 없다가, 아래로 끌면 나타납니다
///
/// [visibility]를 주면 처음에는 **숨어 있고**, 손가락을 아래로 끌면
/// 나타납니다. 내려 읽으면 다시 비킵니다.
///
/// 위에 적은 두 번째 실패(앱바 아이콘 — 아무도 못 찾음)와 같은 위험이
/// 있는 자리입니다. 그래서 나타나는 조건을 **가장 흔한 손짓 하나**로
/// 두었습니다. 목록 어디에서든, 맨 위에서도 아래로 끌기만 하면 나옵니다.
class AskFab extends StatefulWidget {
  /// 언제 보일지. 없으면 **늘 보입니다**(기록 화면·테스트).
  final ValueListenable<bool>? visibility;

  const AskFab({super.key, this.visibility});

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

/// 스크롤 방향을 보고 상담 단추를 보일지 정합니다.
///
/// **[ScrollController]로는 부족합니다.** 맨 위에서 아래로 끌 때 안드로이드
/// 기본 물리(clamping)에서는 위치가 한 픽셀도 움직이지 않아 컨트롤러
/// 리스너가 **한 번도 불리지 않습니다** — 홈의 첫 화면이 바로 그 자리라,
/// 그렇게 만들면 단추가 영영 나타나지 않습니다. 알림은 두 물리 모두에서
/// 옵니다(돌려서 확인했습니다).
class AskFabVisibility extends ValueNotifier<bool> {
  /// 맨 위에서 보일지 — **두 방식을 여기서 고릅니다.**
  ///
  /// - `false`(기본): 평소엔 없다가 **아래로 끌면** 나타납니다.
  /// - `true`: 맨 위에서는 보이고, 내려 읽으면 비킵니다.
  ///
  /// 둘 다 내려 읽으면 비키는 것은 같고, 다른 것은 **맨 위에서 보이는가**
  /// 하나뿐입니다. 어느 쪽이 나은지는 써 봐야 알 수 있어 남겨 둡니다.
  final bool visibleAtTop;

  AskFabVisibility({this.visibleAtTop = false}) : super(false);

  /// 목록을 끌 수 있는지. 처음에는 모르므로 끌 수 있다고 봅니다.
  bool _canScroll = true;

  /// 맨 위인지.
  bool _atTop = true;

  /// 아래로 끌어서 꺼내 놓았는지.
  bool _revealed = false;

  /// 스크롤이 움직였을 때. 방향과 위치를 함께 봅니다.
  void update(ScrollNotification notification) {
    _canScroll = notification.metrics.maxScrollExtent > 0;
    _atTop = notification.metrics.pixels <= 0;

    if (notification is UserScrollNotification) {
      switch (notification.direction) {
        case ScrollDirection.forward: // 손가락을 아래로 끄는 중
          _revealed = true;
        case ScrollDirection.reverse: // 내려 읽는 중
          _revealed = false;
        case ScrollDirection.idle:
          break; // 손을 뗀 뒤에는 그대로 둡니다.
      }
    }
    _apply();
  }

  /// 목록의 길이가 정해졌을 때.
  ///
  /// **끌 것이 없으면 끌어서 꺼낼 수도 없습니다.** 기록이 적어 홈이 한
  /// 화면에 들어오면 아래로 끌어도 스크롤 알림이 한 건도 오지 않습니다
  /// (돌려서 확인했습니다). 그런 사람에게는 상담으로 가는 길이 막힙니다.
  ///
  /// [ScrollMetricsNotification]은 [ScrollNotification]의 하위 타입이
  /// **아니라서** 따로 받아야 합니다.
  ///
  /// 이 값은 **양쪽으로 다시 계산합니다.** 예전에는 짧을 때 켜기만 하고
  /// 끄지 않았는데, 홈은 자료를 비동기로 읽어 첫 프레임이 짧습니다. 그래서
  /// 늘 켜진 채로 시작해 '맨 위에서 보이는' 동작이 되어 있었습니다.
  void updateMetrics(ScrollMetrics metrics) {
    _canScroll = metrics.maxScrollExtent > 0;
    _apply();
  }

  void _apply() {
    value = !_canScroll || _revealed || (visibleAtTop && _atTop);
  }
}

class _AskFabState extends State<AskFab> {
  @override
  Widget build(BuildContext context) {
    final visibility = widget.visibility;
    if (visibility == null) return _button(context);

    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      builder: (context, visible, child) {
        // 숨었을 때는 눌리지도, 낭독되지도 않아야 합니다. 보이지 않는
        // 단추가 손가락을 먹으면 그 자리의 카드를 누를 수 없습니다.
        return IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(
            excluding: !visible,
            child: AnimatedScale(
              scale: visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: child,
            ),
          ),
        );
      },
      child: _button(context),
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
