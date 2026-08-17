import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';

/// 로그인이 풀리면 로그인 화면으로 보냅니다.
///
/// gotrue는 갱신에 실패하면 세션을 지우고 signedOut을 흘리는데, 앱에 그걸 듣는
/// 곳이 없었습니다. 세션이 없으면 supabase는 anon 키로 요청을 보내고 RLS가
/// 오류가 아니라 **200 + 0행**을 돌려줍니다. 그래서 화면들이 "아이 정보를 먼저
/// 등록해 주세요"라고 말했습니다 — 아이는 멀쩡히 있고 로그인이 풀린 것뿐인데요.
///
/// **화면이 아니라 앱 전체에서 하나만 듣습니다.** 예전에는 MainShell에 달았는데,
/// AuthGate가 아이 없는 사용자를 온보딩으로 **직접** 보내므로 그 화면에서는
/// MainShell이 아예 만들어지지 않습니다. 갓 가입한 사람이 아이 정보를 적는 동안
/// 세션이 풀리면 아무도 로그인 화면으로 보내지 않았고, 입력을 마치는 순간
/// 저장이 실패했습니다. 화면마다 손으로 달면 이렇게 하나씩 빠집니다.
///
/// [NavigatorObserver]를 물려받은 이유는 **맨 위 라우트를 알아야 하기**
/// 때문입니다. 앱을 열자마자 저장된 세션 복원이 실패하면 AuthGate와 이쪽이
/// 동시에 로그인 화면으로 보내려 하는데, 목적지가 같아도 화면은 두 번
/// 만들어집니다. 관찰자가 되면 [navigator]도 딸려 오므로 이동에 GlobalKey가
/// 따로 필요 없습니다.
class AuthRedirect extends NavigatorObserver {
  StreamSubscription<AuthState>? _subscription;

  /// 맨 위에 있는 라우트 이름.
  String? _topRoute;

  /// 흐름을 듣기 시작합니다. 앱이 사는 동안 한 번만 부릅니다.
  void listenTo(Stream<AuthState> authState) {
    _subscription = authState.listen(
      (state) {
        if (state.event != AuthChangeEvent.signedOut) return;
        if (_topRoute == AppRoutes.login) return;
        navigator?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      },
      // **onError를 반드시 답니다.** gotrue 문서가 못 박아 둔 것입니다. 이 흐름은
      // BehaviorSubject라, 망이 끊겨 토큰 갱신이 실패하면 에러가 흐름에 실리고
      // onError가 없는 구독은 Zone의 잡히지 않은 비동기 오류가 됩니다. 게다가
      // 그 에러를 들고 있어서 새 구독자에게 그대로 다시 흘립니다.
      onError: (Object e) => debugPrint('인증 상태 흐름 오류: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _topRoute = route.settings.name;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _topRoute = newRoute?.settings.name;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _topRoute = previousRoute?.settings.name;
}
