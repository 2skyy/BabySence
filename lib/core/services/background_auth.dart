import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 백그라운드 isolate에 넘기는 로그인 정보의 신호 이름.
const String backgroundAuthSignal = 'noise_auth';

/// 지금 로그인 정보를 백그라운드에 넘깁니다.
///
/// ## 왜 이런 게 필요한가
///
/// 소음은 앱을 닫아도 계속 재야 해서 **별도 isolate**에서 돕니다. 거기서도
/// DB에 쓰려면 로그인 상태가 필요한데, 예전에는 그쪽이 `Supabase.initialize`를
/// 한 번 더 부르면서 **화면 쪽과 같은 저장소를 썼습니다.**
///
/// Supabase의 로그인 갱신은 한 번 쓰면 버려지는 티켓입니다. 티켓 A를 내면
/// B를 받고, B를 내면 C를 받습니다. 그런데 두 쪽이 같은 서랍에서 티켓을
/// 꺼내 가니 이런 일이 벌어졌습니다.
///
///   21시  재우기 시작 → 백그라운드가 깨어남
///         화면이 꺼지면 화면 쪽은 갱신을 멈춥니다
///         백그라운드만 밤새 티켓을 갈아치웁니다 (A→B→…→Z)
///   07시  앱을 열면 화면 쪽은 몇 시간 전 티켓을 들고 있습니다
///         이미 쓴 티켓이라 서버가 거절 → 로그아웃 → 서랍까지 비움
///
/// 그다음이 더 나빴습니다. 로그아웃된 채로 조회하면 오류가 아니라 **빈
/// 목록**이 옵니다(RLS가 "이 사람 것"만 주는데 그 사람이 없으므로). 그래서
/// 화면은 "아이 정보가 없어 결과를 만들지 못했습니다"라고 말했습니다.
/// 아이는 멀쩡히 있고, 밤새 잰 8시간이 사라졌습니다.
///
/// ## 지금 하는 일
///
/// 백그라운드는 **스스로 갱신하지 않고 저장소도 쓰지 않습니다**
/// (`main.dart`의 `onStart`). 대신 화면이 DB에 쓸 일이 생기기 직전에 최신
/// 토큰을 실어 보냅니다. 티켓 관리가 화면 한 곳으로 모입니다.
///
/// 백그라운드가 DB에 쓰는 순간은 둘뿐이고, 둘 다 **화면이 살아 있는 때**
/// 입니다 — 측정을 시작할 때 수면 기록 행을 만들고, 멈출 때 그 행을 닫습니다.
/// 그래서 그 두 번만 보내면 됩니다.
Future<void> pushAuthToBackground() async {
  if (kIsWeb) return;

  final auth = Supabase.instance.client.auth;
  var session = auth.currentSession;
  if (session == null) return;

  // 만료됐으면 **화면 쪽에서** 갱신합니다. 티켓 사슬을 쥔 쪽이 여기입니다.
  if (session.isExpired) {
    try {
      session = (await auth.refreshSession()).session;
    } catch (e) {
      debugPrint('백그라운드에 넘길 세션을 갱신하지 못했습니다: $e');
      return;
    }
  }
  if (session == null) return;

  FlutterBackgroundService().invoke(
    backgroundAuthSignal,
    {'session': jsonEncode(session.toJson())},
  );
}
