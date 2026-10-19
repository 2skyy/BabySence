import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_project/core/services/auth_redirect.dart';
import 'package:flutter_project/routes/app_routes.dart';

/// [AuthRedirect]를 **실제로 돌려** 봅니다.
///
/// 이 저장소의 인증 관련 검증은 그동안 소스를 문자열로 훑는 것뿐이었습니다.
/// 그래서 "로그인 화면으로 두 번 보낸다" 같은 결함을 하나도 잡지 못했습니다 —
/// 문자열은 멀쩡히 다 들어 있었으니까요.
///
/// [AuthRedirect]는 Supabase에 직접 붙지 않고 흐름을 **받기만** 하므로, 여기서
/// 가짜 흐름을 물려 실제 화면 전환을 확인할 수 있습니다.
void main() {
  const signedOut = AuthState(AuthChangeEvent.signedOut, null);

  /// 로그인 화면으로 몇 번 보냈는지 셉니다. "두 번 보내지 않는다"는 화면만
  /// 봐서는 확인할 수 없습니다 — 두 번째 로그인 화면도 똑같이 생겼습니다.
  late _LoginPushCounter counter;
  late StreamController<AuthState> auth;
  late AuthRedirect redirect;

  setUp(() {
    counter = _LoginPushCounter();
    auth = StreamController<AuthState>();
    redirect = AuthRedirect()..listenTo(auth.stream);
  });

  tearDown(() {
    redirect.dispose();
    auth.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [redirect, counter],
        home: const Scaffold(body: Text('홈')),
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('로그인 화면')),
          AppRoutes.home: (_) => const Scaffold(body: Text('홈 화면')),
        },
      ),
    );
  }

  testWidgets('로그인이 풀리면 로그인 화면으로 보낸다', (tester) async {
    await pumpApp(tester);
    expect(find.text('홈'), findsOneWidget);

    auth.add(signedOut);
    await tester.pumpAndSettle();

    expect(find.text('로그인 화면'), findsOneWidget);
    // 스택을 남겨 두면 뒤로가기로 이전 사용자의 화면에 돌아갑니다.
    expect(find.text('홈'), findsNothing);
  });

  testWidgets('이미 로그인 화면이면 다시 세우지 않는다', (tester) async {
    // 앱을 열자마자 세션 복원이 실패하면 AuthGate와 이쪽이 동시에 로그인
    // 화면으로 보내려 합니다. 목적지가 같아도 화면은 두 번 만들어집니다.
    await pumpApp(tester);

    auth.add(signedOut);
    await tester.pumpAndSettle();
    auth.add(signedOut);
    await tester.pumpAndSettle();

    expect(counter.pushes, 1);
  });

  testWidgets('로그인 화면에서 나간 뒤에는 다시 보낸다', (tester) async {
    // 가드가 라우트 이름을 계속 따라가지 못하고 한 번 잠긴 채로 굳으면,
    // 다시 로그인한 사용자는 세션이 풀려도 그 자리에 남습니다.
    await pumpApp(tester);

    auth.add(signedOut);
    await tester.pumpAndSettle();
    expect(counter.pushes, 1);

    // 로그인에 성공해 홈으로 돌아간 상황.
    redirect.navigator!
        .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    await tester.pumpAndSettle();

    auth.add(signedOut);
    await tester.pumpAndSettle();

    expect(counter.pushes, 2);
  });

  testWidgets('signedOut이 아닌 이벤트에는 움직이지 않는다', (tester) async {
    await pumpApp(tester);

    auth.add(const AuthState(AuthChangeEvent.tokenRefreshed, null));
    auth.add(const AuthState(AuthChangeEvent.signedIn, null));
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(counter.pushes, 0);
  });

  testWidgets('흐름에 실린 오류가 앱을 죽이지 않는다', (tester) async {
    // gotrue는 재시도 가능한 갱신 실패를 이 흐름에 에러로 싣습니다. onError가
    // 없으면 Zone의 잡히지 않은 비동기 오류가 됩니다.
    await pumpApp(tester);

    auth.addError(Exception('망이 끊겼습니다'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('홈'), findsOneWidget);
  });

  testWidgets('dispose한 뒤에는 듣지 않는다', (tester) async {
    await pumpApp(tester);

    redirect.dispose();
    auth.add(signedOut);
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(counter.pushes, 0);
  });
}

/// 로그인 화면이 몇 번 세워졌는지 셉니다.
class _LoginPushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == AppRoutes.login) pushes++;
  }
}
