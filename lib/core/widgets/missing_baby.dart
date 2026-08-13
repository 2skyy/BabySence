import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

/// 저장하려는데 아이가 없을 때 안내합니다.
///
/// **"불러오지 못했다"와 "아직 등록하지 않았다"는 다른 말입니다.**
/// 기록 화면 다섯이 둘을 같은 문구로 묶어, 온보딩을 '나중에 하기'로 건너뛴
/// 사람에게 "아이 정보를 불러오지 못해 저장하지 않았습니다. 화면을 다시
/// 열어 주세요"라고 말했습니다. 조회는 실패한 적이 없고 아이가 없을 뿐인데
/// 원인을 틀리게 짚었고, 시키는 대로 화면을 다시 열어도 달라지는 게
/// 없었습니다.
///
/// [loadFailed]는 화면을 열 때의 조회가 예외로 끝났는지입니다.
void notifyMissingBaby(
  BuildContext context, {
  required bool loadFailed,
  VoidCallback? onRegistered,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  if (loadFailed) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('아이 정보를 불러오지 못해 저장하지 않았습니다. '
            '연결을 확인하고 화면을 다시 열어 주세요.'),
      ),
    );
    return;
  }

  // 아이가 없는 것이라 화면을 다시 열어도 소용없습니다. 등록으로 보냅니다.
  messenger.showSnackBar(
    SnackBar(
      content: const Text('먼저 아이 정보를 등록해 주세요.'),
      action: SnackBarAction(
        label: '등록하기',
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.onboarding);
          onRegistered?.call();
        },
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}
