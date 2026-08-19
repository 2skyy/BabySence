import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/feeding_reminder/feeding_schedule.dart';

/// 홈에는 오래 '다음 수유까지 N시간' 같은 예측을 넣지 않는다는 결정이
/// 있었습니다. 이유는 "아이마다 간격이 다르고 그 기준을 정한 바가 없어
/// 숫자를 지어내는 것이 되기 때문"이었습니다.
///
/// 이제 간격을 **보호자가 정합니다.** 그 선만 지키면 됩니다 — 앱이 대신
/// 정하지 않는다는 것.
void main() {
  final lastFed = DateTime(2026, 8, 12, 11, 30);

  group('다음 시각', () {
    test('마지막 수유에 정한 간격을 더한다', () {
      const gap = Duration(hours: 3);
      final schedule = FeedingSchedule(lastFedAt: lastFed, interval: gap);
      expect(schedule.nextAt, DateTime(2026, 8, 12, 14, 30));
    });

    test('간격을 정하지 않았으면 계산하지 않는다', () {
      // 앱이 임의의 값을 채우면 그 숫자가 근거처럼 읽힙니다.
      final schedule = FeedingSchedule(lastFedAt: lastFed);
      expect(schedule.nextAt, isNull);
      expect(schedule.remainingAt(lastFed), isNull);
    });

    test('수유 기록이 없으면 계산하지 않는다', () {
      const schedule = FeedingSchedule(interval: Duration(hours: 3));
      expect(schedule.nextAt, isNull);
    });
  });

  group('남은 시간', () {
    final schedule =
        FeedingSchedule(lastFedAt: lastFed, interval: const Duration(hours: 3));

    test('아직 남았으면 양수', () {
      final left = schedule.remainingAt(DateTime(2026, 8, 12, 13, 10));
      expect(left, const Duration(hours: 1, minutes: 20));
      expect(schedule.isOverdueAt(DateTime(2026, 8, 12, 13, 10)), isFalse);
    });

    test('지났으면 지났다고 본다', () {
      expect(schedule.isOverdueAt(DateTime(2026, 8, 12, 15, 0)), isTrue);
    });

    test('정확히 그 시각은 아직 지난 것이 아니다', () {
      expect(schedule.isOverdueAt(DateTime(2026, 8, 12, 14, 30)), isFalse);
    });
  });

  group('읽는 말', () {
    test('남은 시간', () {
      expect(formatRemaining(const Duration(hours: 1, minutes: 20)), '1시간 20분 뒤');
      expect(formatRemaining(const Duration(minutes: 40)), '40분 뒤');
      expect(formatRemaining(const Duration(hours: 2)), '2시간 뒤');
    });

    test('지난 시간은 음수로 보여주지 않는다', () {
      // '-1시간'으로 두면 읽는 사람이 한 번 더 생각해야 합니다.
      expect(formatRemaining(const Duration(hours: -1)), '1시간 지났어요');
      expect(formatRemaining(const Duration(minutes: -25)), '25분 지났어요');
    });

    test('지금은 지금이라고 한다', () {
      expect(formatRemaining(Duration.zero), '지금이에요');
      expect(formatRemaining(const Duration(seconds: -20)), '지금이에요');
    });

    test('간격', () {
      expect(formatInterval(const Duration(hours: 3)), '3시간');
      expect(formatInterval(const Duration(hours: 3, minutes: 30)), '3시간 30분');
    });

    test('시각은 오전·오후로', () {
      expect(formatClock(DateTime(2026, 8, 12, 14, 30)), '오후 2:30');
      expect(formatClock(DateTime(2026, 8, 12, 0, 5)), '오전 12:05');
      expect(formatClock(DateTime(2026, 8, 12, 12, 0)), '오후 12:00');
    });
  });

  group('처음 값', () {
    test('개월 수에 따라 다르다', () {
      expect(suggestedInterval(1), const Duration(hours: 3));
      expect(suggestedInterval(5), const Duration(hours: 4));
      expect(suggestedInterval(10), const Duration(hours: 5));
    });

    test('고를 수 있는 값 안에 있다', () {
      // 시트에 없는 값이 미리 골라져 있으면 아무것도 선택돼 보이지 않습니다.
      for (final months in [0, 3, 4, 6, 7, 24]) {
        expect(selectableIntervals, contains(suggestedInterval(months)));
      }
    });
  });

  group('알림 문구', () {
    test('이름을 알면 제목에서 부른다', () {
      // 함께 키우는 두 사람이 각자 기기에서 받으므로, 누구 이야기인지가
      // 제목에 있어야 합니다.
      expect(feedingNotificationTitle('지호'), '지호 수유 시간이 되었어요');
    });

    test('이름을 모르면 지어내지 않는다', () {
      // '아이'처럼 채워 넣으면 앱이 모르는 것을 아는 척하게 됩니다.
      for (final blank in [null, '', '   ']) {
        expect(feedingNotificationTitle(blank), '수유 시간이 되었어요',
            reason: '${blank == null ? 'null' : '"$blank"'}에서 이름을 지어냈습니다');
      }
    });

    test('앞뒤 공백은 다듬는다', () {
      // 다듬는 규칙 자체는 baby_service_test.dart가 봅니다.
      expect(feedingNotificationTitle('  지호 '), '지호 수유 시간이 되었어요');
    });

    test('본문은 마지막 수유 시각과 간격을 적는다', () {
      // 왜 지금 울리는지가 있어야 합니다.
      final body = feedingNotificationBody(
        lastFedAt: DateTime(2026, 8, 19, 14, 10),
        interval: const Duration(hours: 3),
      );
      expect(body, '마지막 수유 오후 2:10 · 3시간 간격');
    });

    test('본문에 숫자 뒤 조사를 붙이지 않는다', () {
      // 예전에는 '${formatClock(at)}로 정하신 시간이 되었어요.'였습니다.
      // 조사는 앞 숫자를 읽는 방식을 따라 '로'와 '으로'로 갈리는데 늘
      // '로'였습니다 — '2:10로'. 조사가 필요 없는 문장이라야 안 틀립니다.
      for (final minute in [0, 5, 10, 30]) {
        final body = feedingNotificationBody(
          lastFedAt: DateTime(2026, 8, 19, 14, minute),
          interval: const Duration(hours: 3),
        );
        expect(body.contains('로 '), isFalse, reason: body);
        expect(body.endsWith('로'), isFalse, reason: body);
      }
    });

    test('30분 단위 간격도 그대로 읽는다', () {
      expect(
        feedingNotificationBody(
          lastFedAt: DateTime(2026, 8, 19, 9, 5),
          interval: const Duration(hours: 3, minutes: 30),
        ),
        '마지막 수유 오전 9:05 · 3시간 30분 간격',
      );
    });
  });

  group('이름이 알림까지 흘러가는가', () {
    // 문구 함수는 위에서 봤습니다. 비어 있던 것은 배선입니다.
    String read(String path) => File(path).readAsStringSync();

    test('예약이 받은 이름을 제목 함수에 넘긴다', () {
      final source =
          read('lib/features/feeding_reminder/feeding_reminder_service.dart');
      expect(source.contains('title: feedingNotificationTitle(babyName),'),
          isTrue);
    });

    test('카드와 홈이 아이 이름을 넘긴다', () {
      expect(
        read('lib/features/feeding_reminder/next_feeding_card.dart')
            .contains('babyName: widget.babyName'),
        isTrue,
      );
      expect(
        read('lib/features/home/home_page.dart').contains('babyName: _baby?.name'),
        isTrue,
        reason: '홈이 이름 없이 예약하고 있습니다',
      );
    });
  });
}
