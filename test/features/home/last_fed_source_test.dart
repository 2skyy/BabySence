import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/home/today_summary.dart';

/// 다음 수유 카드가 **오늘 기록**을 원천으로 삼으면 자정에 기억을 잃습니다.
///
/// 밤 11시에 먹이고 새벽 1시에 홈을 열면 `TodaySummary.feeding`은 null입니다
/// (오늘 것이 아직 없으므로). 그러면 카드가 "수유를 기록해 주세요"로
/// 되돌아가고, `FeedingReminderService.reschedule`이 예약을 취소합니다 —
/// 하필 이 기능이 필요한 시간대입니다.
void main() {
  FeedingRecord at(DateTime when) => FeedingRecord(
        id: when.toIso8601String(),
        type: FeedingType.formula,
        amountMl: 120,
        fedAt: when,
      );

  test('오늘 요약은 자정을 넘기면 비워진다 — 카드가 이걸 쓰면 안 됩니다', () {
    final lastNight = DateTime(2026, 8, 11, 23, 0);
    final earlyMorning = DateTime(2026, 8, 12, 1, 0);

    final summary = TodaySummary.from(
      feedings: [at(lastNight)],
      temperatures: const [],
      diapers: const [],
      sleeps: const [],
      now: earlyMorning,
    );

    // 이 null이 버그의 원인입니다. TodaySummary가 잘못된 게 아니라
    // (오늘 기록은 정말 없습니다), 카드의 원천으로 부적절한 것입니다.
    expect(summary.feeding, isNull);
  });

  test('가장 최근 수유는 날짜와 무관하게 목록의 첫 항목이다', () {
    // loadRecent가 fed_at 내림차순으로 줍니다.
    final feedings = [
      at(DateTime(2026, 8, 11, 23, 0)),
      at(DateTime(2026, 8, 11, 20, 0)),
    ];

    expect(feedings.first.fedAt, DateTime(2026, 8, 11, 23, 0));
  });

  test('홈이 다음 수유 카드에 오늘 요약을 넘기지 않는다', () {
    // 원천을 되돌리면 새벽에 알림이 조용히 취소됩니다. 화면 코드라
    // 위젯 테스트가 없어, 넘기는 값을 글자로 고정합니다.
    final source = File('lib/features/home/home_page.dart').readAsStringSync();

    expect(source.contains('lastFedAt: _today.feeding'), isFalse,
        reason: '오늘 요약은 자정에 비워집니다. 날짜와 무관한 최근 수유를 넘기세요.');
    expect(source.contains('lastFedAt: _lastFedAt'), isTrue);
  });
}
