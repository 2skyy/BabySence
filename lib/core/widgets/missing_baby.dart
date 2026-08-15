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
/// 상태가 **셋**입니다. 둘로 묶으면 아직 모르는 것이 미등록으로 샙니다.
enum BabyLookup {
  /// 아직 조회가 안 끝났습니다. 첫 프레임에는 늘 이 상태입니다.
  loading,

  /// 조회가 예외로 끝났습니다.
  failed,

  /// 조회는 끝났고 아이가 없습니다.
  none,
}

void notifyMissingBaby(
  BuildContext context, {
  required BabyLookup state,
  VoidCallback? onRegistered,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  if (state == BabyLookup.loading) {
    // **세 번째 상태.** 예전에는 이것이 미등록으로 새어, 아이가 있는
    // 사람에게 "먼저 아이 정보를 등록해 주세요"라고 말했습니다. 안내를
    // 따라 등록하면 아이가 하나 더 생기는데, loadCurrent()는 가장 먼저
    // 만든 행을 쓰므로 그 아이는 어디에도 보이지 않고 지울 수도 없습니다.
    messenger.showSnackBar(
      const SnackBar(
        content: Text('아이 정보를 불러오는 중입니다. 잠시 후 다시 눌러 주세요.'),
      ),
    );
    return;
  }

  if (state == BabyLookup.failed) {
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
