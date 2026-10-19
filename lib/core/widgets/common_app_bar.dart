import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 앱 전체가 쓰는 앱바.
///
/// 예전에는 화면마다 `AppBar`를 직접 만들었습니다(19곳). 그러다 보니 뒤로가기
/// 화살표가 두 종류로 갈렸고, 흰 바탕이 박힌 곳이 남아 다크 모드에서 그
/// 화면만 밝게 떴습니다. 한 곳에서 만들면 그런 어긋남이 생기지 않습니다.
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// 오른쪽에 붙는 버튼들.
  final List<Widget>? actions;

  /// 가운데 정렬. 목록 화면은 왼쪽 정렬이 읽기 편해 끄기도 합니다.
  final bool centerTitle;

  /// 뒤로가기 버튼을 둘지. 첫 화면처럼 돌아갈 곳이 없으면 false로 둡니다.
  /// 눌러도 아무 일이 없는 버튼은 고장으로 보입니다.
  final bool showBack;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    // 돌아갈 곳이 있을 때만 화살표를 그립니다.
    final canPop = showBack && Navigator.canPop(context);

    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      backgroundColor: context.colors.surface,
      foregroundColor: context.colors.textPrimary,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            )
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
