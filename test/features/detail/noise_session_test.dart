import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 측정을 끝맺는 흐름을 글자로 고정합니다.
///
/// 이 화면은 위젯 테스트가 없고, 백그라운드 isolate와 신호로만 통신해
/// 테스트로 돌리기 어렵습니다. 그런데 여기서 틀리면 **8시간 잰 밤의 판정이
/// 통째로 사라집니다.** 그래서 되돌아가는 것을 글자로 막습니다.
///
/// 아래 성질들은 모두 실제로 한 번씩 깨졌던 것입니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final page = read('lib/features/detail/noise_test_page.dart');
  final main = read('lib/main.dart');
  final tracker = read('lib/core/services/noise_tracker.dart');

  group('종료 신호를 기다리는 자리', () {
    test('측정 시작을 못 본 화면도 기다린다', () {
      // 밤잠의 표준 흐름입니다 — 저녁에 시작하고, 화면을 나가거나 앱이 죽고,
      // 아침에 다시 들어와 중지를 누릅니다. 그때 이 화면은 측정 시작을 본
      // 적이 없습니다. 자리를 시작 분기에서만 만들면 기다리지 않고 지나가
      // 결과가 안 나옵니다.
      expect(page.contains('void _armSessionWait()'), isTrue);

      final toggle = page.substring(
        page.indexOf('void _toggleNoiseMeasurement()'),
        page.indexOf('/// 종료 신호를 받을 자리를 만듭니다'),
      );
      expect(
        toggle.indexOf('_armSessionWait()') < toggle.indexOf("invoke('stopNoiseOnly')"),
        isTrue,
        reason: '중지를 보내기 전에 기다릴 자리를 만들어야 합니다',
      );
    });

    test('완전히 끄기도 결과를 연다', () {
      // 백그라운드는 끝맺음을 알려주지만, 받아서 결과를 여는 것은 화면 몫
      // 입니다. 예전에는 그냥 껐고, 그 밤의 판정이 만들어지지 않았습니다.
      final button = page.substring(page.indexOf("invoke('stopService')") - 600);
      expect(button.contains('if (wasMeasuring) _armSessionWait();'), isTrue);
      expect(button.contains('if (wasMeasuring) await _showResult();'), isTrue);
    });

    test('두 번째 종료 신호가 결과를 덮지 않는다', () {
      // 중지한 뒤 '완전히 끄기'를 누르면 신호가 한 번 더 옵니다. 두 번째는
      // 빈 값이라 방금 받은 결과를 null로 덮고, 이미 완료된 Completer에
      // complete을 불러 StateError를 던집니다.
      expect(
        page.contains('if (pending == null || pending.isCompleted) return;'),
        isTrue,
      );
      expect(page.contains('_sessionEnded?.complete()'), isFalse,
          reason: '가드 없이 complete하면 두 번째 신호에서 던집니다');
    });

    test('고정 시간을 자지 않는다', () {
      expect(page.contains('Future.delayed(const Duration(seconds: 2))'), isFalse);
    });
  });

  group('기록 id', () {
    test('finish 뒤에 읽는다', () {
      // 앞에서 읽으면, 행이 마지막 순간에야 만들어진 밤은 id가 null인 채로
      // 나갑니다. 저장은 멀쩡히 됐는데 화면은 실패로 봅니다.
      final end = main.substring(
        main.indexOf('Future<void> endNoiseSession()'),
        main.indexOf('void stopNoiseMeasurement()'),
      );
      expect(end.contains('final result = await noiseTracker.finish();'), isTrue);
      expect(end.contains('noiseTracker.sleepRecordId'), isFalse,
          reason: 'finish() 전에 읽으면 안 됩니다');
    });

    test('결과가 id에 매이지 않는다', () {
      // 집계는 메모리에서 옵니다. 행을 못 만들었다고 판정까지 버릴 이유가
      // 없습니다.
      expect(page.contains('_endedSleepRecordId'), isFalse);
    });
  });

  group('저장 실패를 숨기지 않는다', () {
    test('화면이 저장 실패를 말한다', () {
      expect(page.contains('수면 기록을 저장하지 못했습니다'), isTrue);
      expect(page.contains('_endedSaved'), isTrue);
    });

    test('그래도 결과는 보여준다', () {
      // 판정은 앱이 계산합니다. 저장이 실패했다고 결과까지 버리면, 다시 만들
      // 수 없는 밤을 잃습니다.
      final notice = page.indexOf('수면 기록을 저장하지 못했습니다');
      final save = page.indexOf('AssessmentService.save');
      expect(notice < save, isTrue, reason: '안내 뒤에도 판정 저장이 이어져야 합니다');
    });
  });

  group('소음 수치는 저장하지 않는다', () {
    test('측정 중 화면에는 실시간으로 보여준다', () {
      // 이건 리팩터 전후로 같습니다. 매 콜백마다 UI로 갑니다.
      expect(main.contains("service.invoke('update_db'"), isTrue);
      expect(page.contains("service.on('update_db')"), isTrue);
    });

    test('sleep_records에 수치를 적지 않는다', () {
      // 판정 한 행(assessments.inputs)이 이미 같은 숫자를 들고 있습니다.
      expect(tracker.contains("'average_db'"), isFalse);
      expect(tracker.contains("'sample_count'"), isFalse);
    });

    test('시작 시각이 행을 만든 시각이 아니다', () {
      // 시작할 때 망이 없으면 행은 몇 분 뒤에 생깁니다. 그때 now()를 쓰면
      // 표본은 28,800개인데 수면 길이가 0분인 행이 남습니다.
      expect(tracker.contains("'started_at': toDbTime(_startedAt ?? DateTime.now())"),
          isTrue);
    });
  });
}
