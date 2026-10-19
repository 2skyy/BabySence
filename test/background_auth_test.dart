import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 백그라운드 isolate가 **화면과 로그인 저장소를 나눠 쓰지 않게** 막습니다.
///
/// Supabase의 갱신 토큰은 한 번 쓰면 버려지는 티켓입니다. 티켓 A를 내면 B를
/// 받고, B를 내면 C를 받습니다. 두 쪽이 같은 서랍에서 꺼내 가면 사슬이
/// 끊깁니다.
///
///   21시  재우기 시작. 화면이 꺼지면 화면 쪽은 갱신을 멈춥니다.
///         백그라운드만 밤새 티켓을 갈아치웁니다.
///   07시  앱을 열면 화면은 몇 시간 전 티켓을 내밉니다 → 거절 → 로그아웃
///
/// 그다음이 더 나빴습니다. 로그아웃된 채로 조회하면 오류가 아니라 **빈
/// 목록**이 옵니다(RLS가 "이 사람 것"만 주는데 그 사람이 없으므로). 화면은
/// "아이 정보가 없어 결과를 만들지 못했습니다"라고 말했고, 아이는 멀쩡히
/// 있었고, 밤새 잰 8시간이 사라졌습니다.
///
/// 이 프로젝트가 지키기로 한 첫 번째 원칙 — 조회 실패를 '기록 없음'으로
/// 보여주지 않는다 — 을 정면으로 어기는 자리라 글자로 막습니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final main = read('lib/main.dart');
  final auth = read('lib/core/services/background_auth.dart');
  final page = read('lib/features/detail/noise_test_page.dart');

  group('백그라운드는 로그인을 스스로 관리하지 않는다', () {
    test('티켓을 갈아치우지 않는다', () {
      expect(main.contains('autoRefreshToken: false'), isTrue);
    });

    test('공용 저장소를 건드리지 않는다', () {
      expect(main.contains('localStorage: EmptyLocalStorage()'), isTrue);
    });

    test('딥링크는 화면 쪽만 본다', () {
      expect(main.contains('detectSessionInUri: false'), isTrue);
    });

    test('화면이 넘긴 세션을 받는 자리가 있다', () {
      expect(main.contains('service.on(backgroundAuthSignal)'), isTrue);
      // recoverSession은 만료 전이면 갱신하지 않습니다. setSession은
      // 리프레시 토큰을 **소비하므로** 여기서 쓰면 안 됩니다.
      expect(main.contains('recoverSession'), isTrue);
      expect(main.contains('auth.setSession('), isFalse);
    });
  });

  group('화면이 쓰기 직전에 토큰을 넘긴다', () {
    test('만료됐으면 화면 쪽에서 갱신해 보낸다', () {
      // 티켓 사슬을 쥔 쪽이 화면입니다.
      expect(auth.contains('session.isExpired'), isTrue);
      expect(auth.contains('auth.refreshSession()'), isTrue);
    });

    test('시작 신호보다 먼저 보낸다', () {
      final start = page.substring(page.indexOf('Future<bool> _startMeasuring()'));
      expect(
        start.indexOf('pushAuthToBackground()') <
            start.indexOf("invoke('startNoiseOnly'"),
        isTrue,
      );
    });

    test('중지 신호보다 먼저 보낸다', () {
      // 밤새 재고 아침에 누르는 경우가 흔합니다. 시작할 때 넘긴 토큰은
      // 그때 이미 만료돼 있습니다.
      final toggle = page.substring(
        page.indexOf('void _toggleNoiseMeasurement()'),
        page.indexOf('/// 종료 신호를 받을 자리를 만듭니다'),
      );
      expect(
        toggle.indexOf('pushAuthToBackground()') <
            toggle.indexOf("invoke('stopNoiseOnly')"),
        isTrue,
      );
    });

    test('완전히 끄기에서도 보낸다', () {
      final button = page.substring(page.indexOf("invoke('stopService')") - 1000);
      expect(button.contains('await pushAuthToBackground();'), isTrue);
    });

    test('재는 중이 아니어도 끄는 길에서는 보낸다', () {
      // 화면이 '측정 중이 아님'인 것과 백그라운드에 쓸 것이 남아 있는 것은
      // 다릅니다. 마이크 스트림이 죽으면 main.dart의 onError가 화면 상태만
      // 내리고 집계는 메모리에 남습니다. 그때 토큰을 안 보내면 마지막
      // 쓰기가 401로 실패해 ended_at이 null로 남습니다.
      final button = page.substring(
        page.indexOf('final wasMeasuring = _isNoiseMeasuring;'),
        page.indexOf("invoke('stopService')"),
      );
      expect(button.contains('if (wasMeasuring) await pushAuthToBackground();'),
          isFalse,
          reason: '재는 중일 때만 보내면 안 됩니다');
      expect(button.contains('await pushAuthToBackground();'), isTrue);
    });
  });
}
