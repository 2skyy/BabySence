import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import 'post_auth_route.dart';

/// 앱을 열었을 때 저장된 로그인 세션이 있는지 보고 첫 화면을 정합니다.
///
/// Supabase는 세션을 기기에 보관했다가 초기화 시 복원하므로, 로그인한 사용자가
/// 앱을 껐다 켤 때마다 다시 로그인할 이유가 없습니다.
///
/// 세션이 있으면 [nextRouteAfterSignIn]으로 아이 등록 여부까지 확인해
/// 홈이나 온보딩으로 보냅니다. 로그인 직후와 같은 분기를 쓰는 것입니다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // 첫 프레임 뒤에 이동합니다. build 도중에는 Navigator를 쓸 수 없습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    final route = await nextRouteAfterSignIn();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
