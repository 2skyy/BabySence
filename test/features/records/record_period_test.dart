import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/records/record_period.dart';

/// 주간 원이 하루를 어떻게 자르는지 확인합니다.
///
/// 이 화면에서 가장 틀리기 쉬운 것은 **자정을 넘는 밤잠**입니다. 오후 8시에
/// 재워 새벽 6시에 깬 잠은 원 하나에 담기지 않습니다. 두 날 모두에 그리지
/// 않으면 밤잠이 통째로 사라지거나 한 날에만 붙습니다.
void main() {
  // 2026-08-12는 수요일입니다. 그 주는 8/10(월)에서 8/16(일)까지입니다.
  final wednesday = DateTime(2026, 8, 12, 15);
  final week = RecordPeriod.of(PeriodMode.week, wednesday);

  FeedingRecord feeding(DateTime at) => FeedingRecord(
        id: 'f',
        type: FeedingType.formula,
        fedAt: at,
        amountMl: 100,
      );

  DiaperRecord diaper(DateTime at) => DiaperRecord(
        id: 'd',
        type: DiaperType.stool,
        stoolState: StoolState.golden,
        recordedAt: at,
      );

  SleepRecord sleep(DateTime start, {DateTime? end}) => SleepRecord(
        id: 's',
        type: SleepType.night,
        startedAt: start,
        endedAt: end,
      );

  /// 월요일이 0, 일요일이 6입니다.
  DayPattern dayOf(List<DayPattern> days, int index) => days[index];

  group('RecordPeriod — 주', () {
    test('무슨 요일로 물어도 그 주 월요일에서 시작한다', () {
      for (var day = 10; day <= 16; day++) {
        final range = RecordPeriod.of(PeriodMode.week, DateTime(2026, 8, day, 23, 59));
        expect(range.start, DateTime(2026, 8, 10),
            reason: '8월 $day일이 속한 주');
      }
    });

    test('일곱 날이고 다음 주 월요일 자정은 포함하지 않는다', () {
      expect(week.days.length, 7);
      expect(week.days.first, DateTime(2026, 8, 10));
      expect(week.days.last, DateTime(2026, 8, 16));
      expect(week.end, DateTime(2026, 8, 17));

      expect(week.contains(DateTime(2026, 8, 10)), isTrue);
      expect(week.contains(DateTime(2026, 8, 16, 23, 59, 59)), isTrue);
      expect(week.contains(DateTime(2026, 8, 17)), isFalse);
      expect(week.contains(DateTime(2026, 8, 9, 23, 59, 59)), isFalse);
    });

    test('앞뒤로 옮겨도 월을 넘어 맞는다', () {
      // 8/3(월)의 지난주는 7/27(월)입니다.
      expect(RecordPeriod.of(PeriodMode.week, DateTime(2026, 8, 3)).previous.start,
          DateTime(2026, 7, 27));
      // 12/28(월)의 다음 주는 해를 넘깁니다.
      expect(RecordPeriod.of(PeriodMode.week, DateTime(2026, 12, 28)).next.start,
          DateTime(2027, 1, 4));
    });

    test('달을 넘는 주는 뒤쪽에도 달을 적는다', () {
      expect(week.label, '8월 10일 ~ 16일');
      expect(RecordPeriod.of(PeriodMode.week, DateTime(2026, 7, 30)).label, '7월 27일 ~ 8월 2일');
    });

    test('오늘이 든 주인지 안다 — 다음 주로 넘어가지 못하게 하는 근거', () {
      expect(week.isCurrent(wednesday), isTrue);
      expect(week.next.isCurrent(wednesday), isFalse);
      expect(week.previous.isCurrent(wednesday), isFalse);
    });

    test('끝난 주만 지나갈 수 있다 — 앞날에서는 다음 단추가 죽는다', () {
      // isCurrent만으로 막으면 지금 주만 걸립니다. 앞날의 원을 눌러 다음 주로
      // 들어간 뒤에는 다음 단추가 되살아나 끝없이 앞으로 갈 수 있었습니다.
      expect(week.previous.hasEnded(wednesday), isTrue);
      expect(week.hasEnded(wednesday), isFalse);
      expect(week.next.hasEnded(wednesday), isFalse);
      expect(week.next.next.hasEnded(wednesday), isFalse);
      // 끝 자정은 구간에 들지 않으므로 그 순간 지나간 것이 됩니다.
      expect(week.hasEnded(week.end), isTrue);
    });

    test('하루·달 눈금에서도 앞날은 지나가지 못한다', () {
      // 주 스트립에서 앞날을 누른 뒤 눈금을 좁히면 구간 전체가 앞날이 됩니다.
      final future = RecordPeriod.of(PeriodMode.day, DateTime(2026, 8, 22));
      expect(future.hasEnded(wednesday), isFalse);
      expect(RecordPeriod.of(PeriodMode.month, DateTime(2026, 9, 30))
          .hasEnded(wednesday), isFalse);
      expect(RecordPeriod.of(PeriodMode.day, DateTime(2026, 8, 11))
          .hasEnded(wednesday), isTrue);
    });
  });

  group('자정을 넘는 수면', () {
    test('밤잠이 두 날에 나뉜다', () {
      // 화요일 20시 ~ 수요일 6시.
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [
          sleep(DateTime(2026, 8, 11, 20), end: DateTime(2026, 8, 12, 6)),
        ],
        now: wednesday,
      );

      final tuesday = dayOf(patterns, 1);
      expect(tuesday.sleepArcs.length, 1);
      expect(tuesday.sleepArcs.single.startHour, 20.0);
      expect(tuesday.sleepArcs.single.endHour, 24.0);

      final wed = dayOf(patterns, 2);
      expect(wed.sleepArcs.length, 1);
      expect(wed.sleepArcs.single.startHour, 0.0);
      expect(wed.sleepArcs.single.endHour, 6.0);

      // 한 잠이지만 각 원은 자기 몫만 셉니다.
      expect(tuesday.sleepTotal, const Duration(hours: 4));
      expect(wed.sleepTotal, const Duration(hours: 6));
    });

    test('지난주 일요일 밤에 시작한 잠이 이번 주 월요일에 그려진다', () {
      // 조회는 주 시작 하루 전부터 하므로 이런 행이 실제로 들어옵니다.
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [
          sleep(DateTime(2026, 8, 9, 22), end: DateTime(2026, 8, 10, 6, 30)),
        ],
        now: wednesday,
      );

      final monday = dayOf(patterns, 0);
      expect(monday.sleepArcs.length, 1);
      expect(monday.sleepArcs.single.startHour, 0.0);
      expect(monday.sleepArcs.single.endHour, 6.5);
    });

    test('일요일 밤에 시작해 다음 주로 넘어간 잠은 일요일 몫만 그린다', () {
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [
          sleep(DateTime(2026, 8, 16, 21), end: DateTime(2026, 8, 17, 7)),
        ],
        now: DateTime(2026, 8, 17, 9),
      );

      final sunday = dayOf(patterns, 6);
      expect(sunday.sleepArcs.length, 1);
      expect(sunday.sleepArcs.single.startHour, 21.0);
      expect(sunday.sleepArcs.single.endHour, 24.0);
    });

    test('정확히 자정에 끝난 잠이 다음 날에 길이 0인 호를 만들지 않는다', () {
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [
          sleep(DateTime(2026, 8, 11, 21), end: DateTime(2026, 8, 12)),
        ],
        now: wednesday,
      );

      expect(dayOf(patterns, 1).sleepArcs.single.endHour, 24.0);
      // 수요일 원에는 아무것도 없어야 합니다. 0길이 호는 그려지지 않지만
      // 범례의 '수면 기록 없음'이 뒤집힙니다.
      expect(dayOf(patterns, 2).sleepArcs, isEmpty);
      expect(dayOf(patterns, 2).isEmpty, isTrue);
    });

    test('사흘 넘게 이어진 이상한 기록도 터지지 않고 날마다 잘린다', () {
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [
          sleep(DateTime(2026, 8, 11, 22), end: DateTime(2026, 8, 14, 3)),
        ],
        now: DateTime(2026, 8, 15),
      );

      expect(dayOf(patterns, 1).sleepArcs.single.startHour, 22.0);
      expect(dayOf(patterns, 2).sleepArcs.single.endHour, 24.0);
      expect(dayOf(patterns, 3).sleepArcs.single.startHour, 0.0);
      expect(dayOf(patterns, 4).sleepArcs.single.endHour, 3.0);
      expect(dayOf(patterns, 5).sleepArcs, isEmpty);
    });
  });

  group('아직 끝나지 않은 수면', () {
    test('지금까지만 그리고 미래로 넘어가지 않는다', () {
      // 수요일 13시에 재우기 시작했고 지금은 15시입니다.
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [sleep(DateTime(2026, 8, 12, 13))],
        now: wednesday,
      );

      final wed = dayOf(patterns, 2);
      expect(wed.sleepArcs.single.startHour, 13.0);
      expect(wed.sleepArcs.single.endHour, 15.0);
      expect(wed.sleepArcs.single.ongoing, isTrue);
      expect(wed.hasOngoingSleep, isTrue);
    });

    test('어제 시작해 아직 안 끝난 잠은 어제 몫만 끝난 것으로 본다', () {
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [sleep(DateTime(2026, 8, 11, 21))],
        now: wednesday,
      );

      // 화요일 조각은 자정에서 끊겼으니 '측정 중'이 아닙니다.
      expect(dayOf(patterns, 1).sleepArcs.single.ongoing, isFalse);
      // 지금까지 이어진 수요일 조각만 측정 중입니다.
      expect(dayOf(patterns, 2).sleepArcs.single.endHour, 15.0);
      expect(dayOf(patterns, 2).sleepArcs.single.ongoing, isTrue);
    });

    test('시작이 미래인 기록은 그릴 것이 없다', () {
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [sleep(DateTime(2026, 8, 12, 18))],
        now: wednesday,
      );

      expect(dayOf(patterns, 2).sleepArcs, isEmpty);
    });
  });

  group('수유·배변 점', () {
    test('시:분을 소수 시간으로 옮긴다', () {
      final patterns = buildDayPatterns(
        period: week,
        feedings: [feeding(DateTime(2026, 8, 12, 14, 30))],
        diapers: [diaper(DateTime(2026, 8, 12, 3, 15))],
        now: wednesday,
      );

      final wed = dayOf(patterns, 2);
      // 점은 시각순으로 정렬됩니다.
      expect(wed.dots.map((d) => d.hour).toList(), [3.25, 14.5]);
      expect(wed.dots.first.kind, DotKind.diaper);
      expect(wed.dots.last.kind, DotKind.feeding);
      expect(wed.feedingCount, 1);
      expect(wed.diaperCount, 1);
    });

    test('자정과 23시 59분이 같은 날의 양 끝에 놓인다', () {
      final patterns = buildDayPatterns(
        period: week,
        feedings: [
          feeding(DateTime(2026, 8, 12)),
          feeding(DateTime(2026, 8, 12, 23, 59)),
        ],
        now: wednesday,
      );

      final hours = dayOf(patterns, 2).dots.map((d) => d.hour).toList();
      expect(hours.first, 0.0);
      expect(hours.last, closeTo(23.983, 0.001));
    });
  });

  group('주 밖과 빈 날', () {
    test('주 밖의 기록은 어느 날에도 들어가지 않는다', () {
      final patterns = buildDayPatterns(
        period: week,
        feedings: [
          feeding(DateTime(2026, 8, 9, 12)), // 지난주 일요일
          feeding(DateTime(2026, 8, 17, 12)), // 다음 주 월요일
        ],
        diapers: [diaper(DateTime(2026, 8, 9, 12))],
        now: wednesday,
      );

      expect(patterns.every((p) => p.dots.isEmpty), isTrue);
    });

    test('기록이 없어도 일곱 날이 빈 채로 서 있고 지어낸 값이 없다', () {
      final patterns = buildDayPatterns(period: week, now: wednesday);

      expect(patterns.length, 7);
      for (var i = 0; i < 7; i++) {
        final p = patterns[i];
        expect(p.day, DateTime(2026, 8, 10 + i));
        expect(p.isEmpty, isTrue);
        expect(p.sleepTotal, Duration.zero);
        expect(p.feedingCount, 0);
        expect(p.diaperCount, 0);
      }
    });
  });

  test('hourOfDay가 자정을 0으로 둔다', () {
    expect(hourOfDay(DateTime(2026, 8, 12)), 0.0);
    expect(hourOfDay(DateTime(2026, 8, 12, 6, 30)), 6.5);
    expect(hourOfDay(DateTime(2026, 8, 12, 23, 45)), 23.75);
  });

  group('RecordPeriod — 하루', () {
    RecordPeriod dayOfDate(DateTime at) => RecordPeriod.of(PeriodMode.day, at);

    test('그 날 자정에서 시작해 하루만 담는다', () {
      final period = dayOfDate(DateTime(2026, 8, 18, 21, 30));

      expect(period.start, DateTime(2026, 8, 18));
      expect(period.end, DateTime(2026, 8, 19));
      expect(period.days, [DateTime(2026, 8, 18)]);
      expect(period.lastDay, DateTime(2026, 8, 18));
      expect(period.contains(DateTime(2026, 8, 18, 23, 59, 59)), isTrue);
      expect(period.contains(DateTime(2026, 8, 19)), isFalse);
    });

    test('앞뒤로 옮길 때 달과 해를 넘는다', () {
      expect(dayOfDate(DateTime(2026, 8, 1)).previous.start,
          DateTime(2026, 7, 31));
      expect(dayOfDate(DateTime(2026, 12, 31)).next.start, DateTime(2027, 1, 1));
    });

    test('머리글에 요일을 함께 적는다', () {
      // 2026-08-18은 화요일입니다.
      expect(dayOfDate(DateTime(2026, 8, 18)).label, '8월 18일 (화)');
    });

    test('전날 밤에 시작한 잠이 그 날 새벽으로 그려진다', () {
      final period = dayOfDate(DateTime(2026, 8, 12));
      final patterns = buildDayPatterns(
        period: period,
        sleeps: [
          sleep(DateTime(2026, 8, 11, 20), end: DateTime(2026, 8, 12, 6)),
        ],
        now: wednesday,
      );

      expect(patterns.length, 1);
      expect(patterns.single.sleepArcs.single.startHour, 0.0);
      expect(patterns.single.sleepArcs.single.endHour, 6.0);
      // 화요일 몫(20~24)은 이 눈금 밖이라 어디에도 없습니다.
      expect(patterns.single.sleepArcs.length, 1);
    });
  });

  group('RecordPeriod — 달', () {
    RecordPeriod monthOf(DateTime at) => RecordPeriod.of(PeriodMode.month, at);

    test('1일에서 시작해 말일까지 담는다', () {
      final period = monthOf(DateTime(2026, 8, 18));

      expect(period.start, DateTime(2026, 8, 1));
      expect(period.end, DateTime(2026, 9, 1));
      expect(period.days.length, 31);
      expect(period.lastDay, DateTime(2026, 8, 31));
    });

    test('달마다 날 수가 다르고 윤년을 안다', () {
      expect(monthOf(DateTime(2026, 2, 10)).days.length, 28);
      // 2028년은 윤년입니다.
      expect(monthOf(DateTime(2028, 2, 10)).days.length, 29);
      expect(monthOf(DateTime(2026, 4, 10)).days.length, 30);
    });

    test('앞뒤로 옮길 때 해를 넘는다', () {
      expect(monthOf(DateTime(2026, 1, 15)).previous.start,
          DateTime(2025, 12, 1));
      expect(monthOf(DateTime(2026, 12, 15)).next.start, DateTime(2027, 1, 1));
    });

    test('말일이 다른 달로 옮겨도 날짜가 밀리지 않는다', () {
      // 3월 31일에서 한 달 뒤로 가면 4월 1일입니다. 날짜를 그대로 들고
      // 옮기면 4월 31일 → 5월 1일로 한 달이 통째로 건너뛰어집니다.
      expect(monthOf(DateTime(2026, 3, 31)).next.start, DateTime(2026, 4, 1));
      expect(monthOf(DateTime(2026, 5, 31)).previous.start,
          DateTime(2026, 4, 1));
    });

    test('머리글에 해와 달을 적는다', () {
      expect(monthOf(DateTime(2026, 8, 18)).label, '2026년 8월');
    });

    test('지난달 마지막 밤잠이 1일 새벽으로 넘어온다', () {
      final period = monthOf(DateTime(2026, 8, 5));
      final patterns = buildDayPatterns(
        period: period,
        sleeps: [
          sleep(DateTime(2026, 7, 31, 21), end: DateTime(2026, 8, 1, 6, 30)),
          sleep(DateTime(2026, 8, 31, 22), end: DateTime(2026, 9, 1, 7)),
        ],
        now: DateTime(2026, 9, 2),
      );

      expect(patterns.length, 31);
      // 8월 1일: 0 ~ 6.5
      expect(patterns.first.sleepArcs.single.startHour, 0.0);
      expect(patterns.first.sleepArcs.single.endHour, 6.5);
      // 8월 31일: 22 ~ 24. 9월 몫은 이 달 밖이라 잘립니다.
      expect(patterns.last.sleepArcs.single.startHour, 22.0);
      expect(patterns.last.sleepArcs.single.endHour, 24.0);
    });
  });

  group('눈금 바꾸기', () {
    test('버튼은 월 · 주 · 일 순서로 선다', () {
      // 화면은 PeriodMode.values 를 그대로 훑어 버튼을 만듭니다. 선언 순서를
      // 바꾸면 버튼 순서가 말없이 따라 바뀌므로 여기에 못 박아 둡니다.
      expect(PeriodMode.values.map((m) => m.label).toList(), ['월', '주', '일']);
    });

    test('보던 날을 그대로 두고 눈금만 바꾼다', () {
      final week = RecordPeriod.of(PeriodMode.week, DateTime(2026, 8, 12));
      final day = DateTime(2026, 8, 12);

      expect(week.withMode(PeriodMode.month, day).start, DateTime(2026, 8, 1));
      expect(week.withMode(PeriodMode.day, day).start, DateTime(2026, 8, 12));
      expect(week.withMode(PeriodMode.week, day).start, DateTime(2026, 8, 10));
    });

    test('지난달을 보다 눈금을 바꿔도 이번 달로 끌려오지 않는다', () {
      final past = RecordPeriod.of(PeriodMode.week, DateTime(2026, 5, 20));
      expect(past.withMode(PeriodMode.month, DateTime(2026, 5, 20)).start,
          DateTime(2026, 5, 1));
    });
  });

  group('끝맺지 못한 수면', () {
    test('하루가 넘도록 열려 있으면 그리지 않는다', () {
      // 소음 측정을 켜 두고 끝맺지 못한 행이 실제로 생깁니다. 그것을
      // '지금까지 자는 중'으로 보고 그리면 한 건이 여러 날을 24시간
      // 수면으로 채웁니다 — 아이가 그렇게 잤다는 근거는 없습니다.
      final stale = sleep(DateTime(2026, 9, 1, 21));  // 끝나지 않음
      final now = DateTime(2026, 9, 20, 10);
      final month = RecordPeriod.of(PeriodMode.month, now);

      final ps = buildDayPatterns(period: month, sleeps: [stale], now: now);

      expect(ps.where((p) => p.sleepArcs.isNotEmpty), isEmpty,
          reason: '열린 지 19일 된 기록으로 잠을 그리면 지어내는 것입니다');
    });

    test('오늘 밤 재는 중인 잠은 그대로 그린다', () {
      // 하루를 넘지 않았으므로 '측정 중'으로 살아 있어야 합니다.
      final tonight = sleep(DateTime(2026, 9, 19, 21));
      final now = DateTime(2026, 9, 20, 6);
      final day = RecordPeriod.of(PeriodMode.day, now);

      final ps = buildDayPatterns(period: day, sleeps: [tonight], now: now);

      expect(ps.single.sleepArcs, isNotEmpty);
      expect(ps.single.hasOngoingSleep, isTrue);
      expect(ps.single.sleepArcs.single.endHour, 6.0);
    });

    test('꼭 하루가 되는 경계에서 아직 그린다', () {
      final edge = sleep(DateTime(2026, 9, 19, 10));
      final now = DateTime(2026, 9, 20, 10); // 정확히 24시간
      final ps = buildDayPatterns(
          period: RecordPeriod.of(PeriodMode.day, now),
          sleeps: [edge], now: now);
      expect(ps.single.sleepArcs, isNotEmpty);
    });
  });
}
