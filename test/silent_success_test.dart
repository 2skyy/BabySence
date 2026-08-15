import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 이 프로젝트의 원칙 1에는 **반대 방향**이 있습니다.
///
///   조회·저장 실패를 "기록 없음"으로 보여주지 않는다.
///   그리고 **실패를 성공이라고 말하지도 않는다.**
///
/// 뒤쪽을 여러 곳에서 어기고 있었습니다. 저장이 실패했는데 결과 화면이
/// 정상적으로 열리고, 0행 갱신이 성공으로 세어지고, 로그인이 풀린 것이
/// "아이 미등록"으로 보였습니다. 전부 **아무 표시 없이** 그랬습니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('로그인이 풀린 것을 미등록으로 보여주지 않는다', () {
    // 세션이 없으면 supabase는 anon 키로 요청을 보내고, RLS가 `to
    // authenticated`라 오류가 아니라 **200 + 0행**을 돌려줍니다. 예외가
    // 없으니 _todayFailed도 StaleNotice도 켜지지 않고, 화면은 "아이 정보를
    // 먼저 등록해 주세요"라고 말합니다. 예약된 수유 알림까지 지워집니다.

    test('세션이 없으면 조회가 예외를 던진다', () {
      final service = read('lib/core/services/baby_service.dart');
      expect(service.contains('_client.auth.currentSession == null'), isTrue);
      expect(service.contains("throw StateError('로그인이 필요합니다.')"), isTrue);
    });

    test('signedOut을 듣고 로그인 화면으로 보낸다', () {
      final shell = read('lib/features/shell/main_shell.dart');
      expect(shell.contains('onAuthStateChange'), isTrue);
      expect(shell.contains('AuthChangeEvent.signedOut'), isTrue);
      expect(shell.contains('pushNamedAndRemoveUntil(AppRoutes.login'), isTrue);
    });

    test('구독을 정리한다', () {
      expect(read('lib/features/shell/main_shell.dart').contains('_authSub?.cancel()'),
          isTrue);
    });
  });

  group('저장 실패를 성공으로 세지 않는다', () {
    test('0행 갱신은 실패다', () {
      // postgrest는 0행 UPDATE에 204를 주고 예외를 던지지 않습니다.
      // 재는 도중에 그 수면 기록을 지웠으면 아무 일도 안 일어나는데
      // saved=true가 됐습니다.
      final tracker = read('lib/core/services/noise_tracker.dart');
      expect(tracker.contains('.select()'), isTrue);
      expect(tracker.contains('if (updated.isEmpty)'), isTrue);
    });

    test('판정 저장 실패를 화면이 말한다', () {
      // 판정 카드는 앱이 계산해 띄우므로, 저장이 실패해도 화면은 똑같이
      // 보입니다. 분석 탭에 없는 것을 저장된 줄 알게 됩니다.
      expect(read('lib/features/detail/temperature_record_page.dart')
          .contains('체온은 기록했지만 판정을 남기지 못했습니다'), isTrue);
      expect(read('lib/features/detail/growth/growth_record_page.dart')
          .contains('판정을 기록에 남기지 못했습니다'), isTrue);
    });

    test('성장 저장이 됐다는 신호가 있다', () {
      // 저장 성공 스낵바가 아예 없어, 됐는지 알 길이 화면에 없었습니다.
      expect(read('lib/features/detail/growth/growth_record_page.dart')
          .contains("'기록했습니다.'"), isTrue);
    });
  });

  group('아직 모르는 것을 없다고 말하지 않는다', () {
    test('아이 조회에 세 번째 상태가 있다', () {
      // 첫 프레임에는 늘 _baby == null입니다. 그것을 미등록으로 묶으면
      // 아이가 있는 사람에게 등록하라고 말하고, 시키는 대로 하면 보이지도
      // 지울 수도 없는 아이가 하나 더 생깁니다.
      final widget = read('lib/core/widgets/missing_baby.dart');
      expect(widget.contains('enum BabyLookup'), isTrue);
      expect(widget.contains('BabyLookup.loading'), isTrue);
      expect(widget.contains('아이 정보를 불러오는 중입니다'), isTrue);
    });

    const screens = [
      'lib/features/detail/temperature_record_page.dart',
      'lib/features/detail/feeding_record_page.dart',
      'lib/features/detail/diaper_record_page.dart',
      'lib/features/detail/sleep_record_page.dart',
      'lib/features/detail/care/care_record_page.dart',
    ];

    for (final path in screens) {
      test('${path.split('/').last} 가 세 상태를 넘긴다', () {
        final source = read(path);
        expect(source.contains('BabyLookup.loading'), isTrue);
        expect(source.contains('loadFailed:'), isFalse,
            reason: '두 상태로 묶던 옛 인자입니다');
      });
    }

    test('끝나지 않은 수면도 기록으로 센다', () {
      // isEmpty가 완료된 수면만 보면, 첫 밤잠을 재는 중인 사람에게
      // "최근 7일 동안 남긴 기록이 없습니다"가 뜹니다 — 기록 탭은 같은
      // 행을 '밤잠 · 측정 중'으로 보여주는데요.
      final summary = read('lib/features/analysis/weekly_summary.dart');
      expect(summary.contains('sleepEntryCount'), isTrue);
      expect(summary.contains('sleepEntryCount == 0 &&'), isTrue);
    });
  });

  group('손에 든 값을 지운 채 오류만 남기지 않는다', () {
    const screens = [
      'lib/features/records/records_page.dart',
      'lib/features/analysis/analysis_page.dart',
      'lib/features/detail/growth/growth_record_page.dart',
    ];

    for (final path in screens) {
      test('${path.split('/').last} 가 낡은 값을 지킨다', () {
        expect(read(path).contains('StaleNotice'), isTrue);
      });
    }
  });

  test('마이크가 죽으면 그 밤을 끝맺는다', () {
    // 예전에는 상태만 내렸습니다. 그때 화면 버튼은 이미 '시작'으로 돌아가
    // 있어 누를 중지가 없고, 시작을 누르면 beginSession()이 집계를 지웁니다.
    final main = read('lib/main.dart');
    final onError = main.substring(
      main.indexOf('onError: (Object error) {'),
      main.indexOf('cancelOnError: false'),
    );
    expect(onError.contains('endingSession = endNoiseSession();'), isTrue);
    expect(onError.contains('noiseSubscription?.cancel();'), isTrue);
  });
}
