import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/core/theme/app_theme.dart';
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/records/day_ring.dart';
import 'package:flutter_project/features/records/record_period.dart';

/// 원과 주간 스트립을 **띄워서** 확인합니다.
///
/// 기록 탭 전체는 Supabase 없이는 조회가 실패해 주간 화면까지 가지 못합니다
/// (records_page_test가 그 실패 경로를 봅니다). 그래서 원은 여기서 따로 띄웁니다.
/// 일곱 개가 한 줄에 서는 화면이라 좁은 기기와 큰 글씨에서 넘치기 쉽습니다.
void main() {
  final now = DateTime(2026, 8, 12, 15);
  final week = RecordPeriod.of(PeriodMode.week, now);

  /// 하루에 밤잠·낮잠·수유 여섯·배변 넷이 있는, 붐비는 주.
  List<DayPattern> busyWeek() {
    final sleeps = <SleepRecord>[];
    final feedings = <FeedingRecord>[];
    final diapers = <DiaperRecord>[];

    for (var i = 0; i < 3; i++) {
      sleeps.add(SleepRecord(
        id: 'n$i',
        type: SleepType.night,
        startedAt: DateTime(2026, 8, 10 + i, 20, 30),
        endedAt: DateTime(2026, 8, 11 + i, 6, 15),
      ));
      sleeps.add(SleepRecord(
        id: 'p$i',
        type: SleepType.nap,
        startedAt: DateTime(2026, 8, 10 + i, 13),
        endedAt: DateTime(2026, 8, 10 + i, 14, 40),
      ));
      for (final h in [7, 10, 13, 16, 19, 23]) {
        feedings.add(FeedingRecord(
          id: 'f$i$h',
          type: FeedingType.formula,
          fedAt: DateTime(2026, 8, 10 + i, h, 10),
          amountMl: 120,
        ));
      }
      for (final h in [8, 12, 18, 22]) {
        diapers.add(DiaperRecord(
          id: 'd$i$h',
          type: DiaperType.stool,
          stoolState: StoolState.golden,
          recordedAt: DateTime(2026, 8, 10 + i, h, 40),
        ));
      }
    }

    return buildDayPatterns(
      period: week,
      sleeps: sleeps,
      feedings: feedings,
      diapers: diapers,
      now: now,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double textScale = 1.0,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Widget strip(List<DayPattern> patterns, {double size = 38}) => Row(
        children: [
          for (final p in patterns)
            Expanded(
              child: DayRingChip(
                pattern: p,
                size: size,
                selected: p.day.day == 12,
                isToday: p.day.day == 12,
                onTap: () {},
              ),
            ),
        ],
      );

  group('주간 스트립', () {
    testWidgets('좁은 기기에서 일곱 개가 넘치지 않는다', (tester) async {
      // 320dp는 지금도 파는 가장 좁은 화면입니다(iPhone SE 1세대).
      await pump(tester, strip(busyWeek(), size: 30), width: 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('글씨를 키워도 넘치지 않는다', (tester) async {
      for (final scale in [1.3, 2.0]) {
        await pump(tester, strip(busyWeek()), width: 320, textScale: scale);
        expect(tester.takeException(), isNull, reason: '배율 $scale');
      }
    });

    testWidgets('날짜를 누르면 그 날이 올라온다', (tester) async {
      final patterns = busyWeek();
      DateTime? tapped;

      await pump(
        tester,
        Row(
          children: [
            for (final p in patterns)
              Expanded(
                child: DayRingChip(
                  pattern: p,
                  selected: false,
                  isToday: false,
                  onTap: () => tapped = p.day,
                ),
              ),
          ],
        ),
      );

      await tester.tap(find.text('14'));
      expect(tapped, DateTime(2026, 8, 14));
    });

    testWidgets('작은 원도 어느 날인지·무엇을 남겼는지 말로 남긴다', (tester) async {
      // 선택은 바탕색으로, 기록 유무는 4dp 점으로만 알립니다 — 둘 다 그림이라
      // 낭독기에는 날짜 숫자만 남고, 어느 날이 골라져 있는지도 어느 날에
      // 기록이 있는지도 들리지 않았습니다.
      await pump(tester, strip(busyWeek()));

      final chips = find.byType(DayRingChip);
      expect(
        tester.getSemantics(chips.at(2)),
        isSemantics(
          label: '수요일, 8월 12일, 수유 6회, 배변 4회.',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(chips.at(4)),
        isSemantics(label: '금요일, 8월 14일, 수유 0회, 배변 0회.',
            isSelected: false),
      );
    });

    testWidgets('일곱 날이 모두 날짜를 달고 선다', (tester) async {
      await pump(tester, strip(busyWeek()));
      for (var day = 10; day <= 16; day++) {
        expect(find.text('$day'), findsOneWidget);
      }
    });
  });

  group('하루 원', () {
    testWidgets('어두운 테마에서도 터지지 않는다', (tester) async {
      // 페인터에는 BuildContext가 없어 색을 밖에서 받습니다. 그 연결이
      // 끊기면 여기서만 밝은 원이 남습니다.
      await pump(tester, DayRing(pattern: busyWeek()[2]), dark: true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기록이 없는 날도 빈 원으로 그려진다', (tester) async {
      final empty = buildDayPatterns(period: week, now: now);
      await pump(tester, DayRing(pattern: empty.first));
      expect(tester.takeException(), isNull);
    });

    testWidgets('화면 낭독기가 읽을 수 있게 숫자를 말로도 남긴다', (tester) async {
      // 원은 그림이라 그대로는 읽히지 않습니다.
      await pump(tester, DayRing(pattern: busyWeek()[2]));

      final semantics = tester.getSemantics(find.byType(DayRing));
      expect(semantics.label, contains('수유 6회'));
      expect(semantics.label, contains('배변 4회'));
    });

    testWidgets('수면을 범례와 같은 말로 읽어 준다', (tester) async {
      // `inHours`로 적으면 50분 잔 날이 '0시간'으로 읽혀, 바로 옆 범례가
      // 적은 '50분'과 다른 잠을 말하게 됩니다.
      final patterns = buildDayPatterns(
        period: week,
        sleeps: [
          SleepRecord(
            id: 'nap',
            type: SleepType.nap,
            startedAt: DateTime(2026, 8, 12, 13),
            endedAt: DateTime(2026, 8, 12, 13, 50),
          ),
        ],
        now: now,
      );

      await pump(
        tester,
        DayRing(pattern: patterns.firstWhere((p) => p.day.day == 12)),
      );

      expect(tester.getSemantics(find.byType(DayRing)).label,
          contains('수면 50분'));
    });

    testWidgets('기록이 없는 날은 0시간이 아니라 없다고 읽어 준다', (tester) async {
      // 범례는 '수면 기록 없음'이라 적습니다. 라벨만 '0시간'이라 읽으면
      // 안 잔 날과 잠깐 잔 날을 귀로는 가릴 수 없습니다.
      final empty = buildDayPatterns(period: week, now: now);
      await pump(tester, DayRing(pattern: empty.first));

      expect(tester.getSemantics(find.byType(DayRing)).label,
          contains('수면 기록 없음'));
    });
  });
}
