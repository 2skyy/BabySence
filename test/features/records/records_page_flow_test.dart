import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/refresh_signal.dart';
import 'package:flutter_project/core/services/sleep_type.dart';
import 'package:flutter_project/core/theme/app_theme.dart';
import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';
import 'package:flutter_project/features/detail/sleep_record_service.dart';
import 'package:flutter_project/features/records/day_ring.dart';
import 'package:flutter_project/features/records/period_records.dart';
import 'package:flutter_project/features/records/record_period.dart';
import 'package:flutter_project/features/records/records_page.dart';

/// 기록 탭을 **기록이 있는 채로** 띄워 봅니다.
///
/// records_page_test.dart는 조회가 실패한 상태만 봅니다. 그 상태에서는 눈금
/// 버튼도 달력도 원도 목록도 아예 그려지지 않아, 화면에서 가장 손이 많이 간
/// 조립부가 통째로 검사 밖에 있었습니다. 실제로 결함 둘이 거기서 났습니다 —
/// 기간을 옮기다 실패하면 스피너가 영영 남는 것, 아이가 없을 때 실패가
/// 삼켜지는 것. 둘 다 부품 테스트는 전부 초록인 채로 났습니다.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  /// 기간의 **모든 날**에 수유·배변·낮잠을 하나씩 둡니다.
  ///
  /// 어느 날을 골라도 목록이 비지 않아야 '날짜를 눌렀더니 바뀌었다'를 볼 수
  /// 있습니다. 조회가 받은 기간을 그대로 채우므로 지난 기간을 펴도 찹니다.
  PeriodRecords filled(RecordPeriod period, {bool truncated = false}) {
    final feedings = <FeedingRecord>[];
    final diapers = <DiaperRecord>[];
    final sleeps = <SleepRecord>[];

    for (final day in period.days) {
      final key = '${day.month}-${day.day}';
      feedings.add(FeedingRecord(
        id: 'f$key',
        type: FeedingType.formula,
        fedAt: DateTime(day.year, day.month, day.day, 10, 30),
        amountMl: 120,
      ));
      diapers.add(DiaperRecord(
        id: 'd$key',
        type: DiaperType.stool,
        stoolState: StoolState.golden,
        recordedAt: DateTime(day.year, day.month, day.day, 12, 40),
      ));
      sleeps.add(SleepRecord(
        id: 's$key',
        type: SleepType.nap,
        startedAt: DateTime(day.year, day.month, day.day, 13),
        endedAt: DateTime(day.year, day.month, day.day, 14, 30),
      ));
    }

    return PeriodRecords(
      feedings: feedings,
      diapers: diapers,
      sleeps: sleeps,
      truncated: truncated,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required PeriodRecordsLoad loader,
    RefreshSignal? refresh,
    DateTime Function()? clock,
    bool dark = false,
  }) async {
    // 세로를 넉넉히 잡습니다. ListView는 화면 밖 자식을 아예 만들지 않아,
    // 실제 높이로는 목록이 검사에 걸리지 않습니다. 좁은 화면과 큰 글씨는
    // day_ring_test.dart와 records_page_test.dart가 따로 봅니다.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: RecordsPage(
        loader: loader,
        refresh: refresh,
        clock: clock ?? DateTime.now,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 눈금 단추. 요일 라벨에도 '월'·'일'이 있어 글자로는 못 가리킵니다.
  Future<void> tapMode(WidgetTester tester, PeriodMode mode) async {
    await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
    await tester.pumpAndSettle();
  }

  /// 기간 이동 화살표. 아이콘으로 가리킵니다.
  Finder arrow(IconData icon) => find.widgetWithIcon(IconButton, icon);

  group('기록이 있을 때', () {
    testWidgets('눈금 버튼·기간 머리글·주 스트립·원·목록이 함께 선다', (tester) async {
      await pump(tester, loader: (p) async => filled(p));

      for (final mode in PeriodMode.values) {
        expect(find.byKey(ValueKey('mode-${mode.name}')), findsOneWidget,
            reason: '${mode.label} 단추가 없습니다');
      }
      expect(find.text(RecordPeriod.of(PeriodMode.week, today).label),
          findsOneWidget);
      // 주 눈금이므로 작은 원 일곱 개.
      expect(find.byType(DayRingChip), findsNWidgets(7));
      expect(find.byType(DayRing), findsOneWidget);
      // 오늘의 목록.
      expect(find.text('분유 · 120ml'), findsOneWidget);
      expect(find.text('대변 · 황금변'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('월 눈금으로 바꾸면 달력이 서고 격자는 쓰지 않는다', (tester) async {
      await pump(tester, loader: (p) async => filled(p));
      await tapMode(tester, PeriodMode.month);

      final month = RecordPeriod.of(PeriodMode.month, today);
      expect(find.text(month.label), findsOneWidget);
      expect(find.byType(DayRingChip), findsNWidgets(month.days.length));
      // 기록하러 가는 입구를 두지 않는다는 원칙이 달력에도 걸립니다.
      expect(find.byType(GridView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('일 눈금으로 바꾸면 달력이 사라지고 그 하루만 남는다', (tester) async {
      await pump(tester, loader: (p) async => filled(p));
      await tapMode(tester, PeriodMode.day);

      expect(find.text(RecordPeriod.of(PeriodMode.day, today).label),
          findsOneWidget);
      expect(find.byType(DayRingChip), findsNothing);
      expect(find.byType(DayRing), findsOneWidget);
      expect(find.text('분유 · 120ml'), findsOneWidget);
    });

    testWidgets('눈금을 바꿔도 보던 날을 잃지 않는다', (tester) async {
      await pump(tester, loader: (p) async => filled(p));

      // 주 → 월 → 주로 돌아와도 같은 주가 나와야 합니다.
      final week = RecordPeriod.of(PeriodMode.week, today).label;
      await tapMode(tester, PeriodMode.month);
      await tapMode(tester, PeriodMode.week);
      expect(find.text(week), findsOneWidget);
    });
  });

  group('기간 이동', () {
    testWidgets('지난 기간을 펴면 다시 읽고 머리글이 바뀐다', (tester) async {
      final asked = <RecordPeriod>[];
      await pump(tester, loader: (p) async {
        asked.add(p);
        return filled(p);
      });

      final thisWeek = RecordPeriod.of(PeriodMode.week, today);
      await tester.tap(arrow(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text(thisWeek.previous.label), findsOneWidget);
      expect(find.text(thisWeek.label), findsNothing);
      expect(asked.last, thisWeek.previous, reason: '지난주를 다시 읽지 않았습니다');
    });

    testWidgets('이번 기간에서는 다음으로 넘어가지 못한다', (tester) async {
      await pump(tester, loader: (p) async => filled(p));

      // 아직 오지 않은 날의 빈 원들은 '기록을 안 남겼다'와 구별되지 않습니다.
      final next = tester.widget<IconButton>(arrow(Icons.chevron_right));
      expect(next.onPressed, isNull);
    });

    testWidgets('지난 기간에서는 다음으로 돌아올 수 있다', (tester) async {
      await pump(tester, loader: (p) async => filled(p));
      await tester.tap(arrow(Icons.chevron_left));
      await tester.pumpAndSettle();

      final next = tester.widget<IconButton>(arrow(Icons.chevron_right));
      expect(next.onPressed, isNotNull);

      await tester.tap(arrow(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text(RecordPeriod.of(PeriodMode.week, today).label),
          findsOneWidget);
    });
  });

  group('실패해도 손에 든 것을 지킨다', () {
    testWidgets('같은 기간에서 실패하면 목록은 두고 낡았다고만 알린다', (tester) async {
      var fail = false;
      final refresh = RefreshSignal();
      addTearDown(refresh.dispose);

      await pump(
        tester,
        refresh: refresh,
        loader: (p) async {
          if (fail) throw StateError('끊김');
          return filled(p);
        },
      );
      expect(find.text('분유 · 120ml'), findsOneWidget);

      fail = true;
      refresh.fire();
      await tester.pumpAndSettle();

      // 지우고 오류만 남기면 방금까지 보던 기록이 사라집니다.
      expect(find.text('분유 · 120ml'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('기간을 옮기다 실패하면 스피너가 남지 않고 다시 시도가 뜬다', (tester) async {
      // 예전에는 여기서 스피너가 **영영** 돌았습니다. 조회는 끝났는데
      // 화면은 계속 불러오는 중이라 말하고, 다시 시도할 길도 없었습니다.
      var fail = false;
      await pump(tester, loader: (p) async {
        if (fail) throw StateError('끊김');
        return filled(p);
      });

      fail = true;
      await tester.tap(arrow(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('아이가 없을 때 난 실패도 말한다', (tester) async {
      // baby == null은 **성공한 조회**라 첫 실패 분기에 걸리지 않습니다.
      // 그때 실패를 삼키면 '아이 정보를 먼저 등록해 주세요' 한 줄만 남습니다.
      var fail = false;
      final refresh = RefreshSignal();
      addTearDown(refresh.dispose);

      await pump(
        tester,
        refresh: refresh,
        loader: (p) async {
          if (fail) throw StateError('끊김');
          return PeriodRecords.noBaby;
        },
      );
      expect(find.text('아이 정보를 먼저 등록해 주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);

      fail = true;
      refresh.fire();
      await tester.pumpAndSettle();

      expect(find.text('아이 정보를 먼저 등록해 주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });

  testWidgets('조회가 잘렸으면 잘렸다고 말한다', (tester) async {
    await pump(tester, loader: (p) async => filled(p, truncated: true));

    expect(
      find.textContaining('일부만 불러왔습니다'),
      findsOneWidget,
      reason: '조용히 자르면 화면이 없는 것을 없다고 단정합니다',
    );
  });

  testWidgets('기록이 없는 기간은 지어내지 않고 없다고 한다', (tester) async {
    await pump(tester, loader: (p) async => const PeriodRecords());

    expect(find.byType(DayRingChip), findsNWidgets(7));
    expect(find.text('수면 기록 없음'), findsOneWidget);
    expect(find.text('수유 0회'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('자정을 넘겨 돌아왔을 때', () {
    // 하단 탭은 IndexedStack이라 화면이 살아 있는 채로 숨겨집니다. 자정을
    // 넘겨도 어제에 머물면, 방금 남긴 새벽 기록이 기간 밖으로 걸러져
    // '기록 없음'으로 보입니다.
    //
    // 예전에는 기준을 **조회 시각**으로 쟀습니다. 그런데 조회는 신호 말고도
    // 당겨서 새로고침·눈금 변경·'다시 시도'가 부르므로, 그중 하나가 자정을
    // 넘겨 먼저 돌면 조회 시각만 새 날이 되어 오늘을 보던 사람이 어제에
    // 갇혔습니다. 시계를 갈아 끼울 수 있게 되어 여기서 직접 확인합니다.

    /// 8월 18일 23시 50분에서 시작해, 옮기면 19일 0시 10분이 됩니다.
    late DateTime fakeNow;
    DateTime clock() => fakeNow;

    setUp(() => fakeNow = DateTime(2026, 8, 18, 23, 50));
    void crossMidnight() => fakeNow = DateTime(2026, 8, 19, 0, 10);

    testWidgets('오늘을 보고 있었으면 새 오늘로 따라간다', (tester) async {
      final refresh = RefreshSignal();
      addTearDown(refresh.dispose);

      await pump(tester,
          refresh: refresh, clock: clock, loader: (p) async => filled(p));
      expect(find.text(RecordPeriod.of(PeriodMode.day, fakeNow).label),
          findsNothing);

      await tester.tap(find.byKey(const ValueKey('mode-day')));
      await tester.pumpAndSettle();
      expect(find.text('8월 18일 (화)'), findsOneWidget);

      crossMidnight();
      refresh.fire();
      await tester.pumpAndSettle();

      expect(find.text('8월 19일 (수)'), findsOneWidget,
          reason: '자정을 넘겼는데 어제에 머물렀습니다');
    });

    testWidgets('지난 날을 일부러 편 사람은 끌어오지 않는다', (tester) async {
      final refresh = RefreshSignal();
      addTearDown(refresh.dispose);

      await pump(tester,
          refresh: refresh, clock: clock, loader: (p) async => filled(p));

      // 지난주로 옮겨 두면 오늘을 따라가지 않아야 합니다.
      await tester.tap(arrow(Icons.chevron_left));
      await tester.pumpAndSettle();
      final past = RecordPeriod.of(PeriodMode.week, fakeNow).previous;
      expect(find.text(past.label), findsOneWidget);

      crossMidnight();
      refresh.fire();
      await tester.pumpAndSettle();

      expect(find.text(past.label), findsOneWidget,
          reason: '펴 둔 지난주에서 끌려 나왔습니다');
    });

    testWidgets('당겨서 새로고침해도 따라가기가 죽지 않는다', (tester) async {
      // 기준을 조회 시각으로 재던 때 정확히 여기서 깨졌습니다. 자정 직후의
      // 새로고침 한 번으로 그 뒤 모든 신호가 무시됐습니다.
      final refresh = RefreshSignal();
      addTearDown(refresh.dispose);

      await pump(tester,
          refresh: refresh, clock: clock, loader: (p) async => filled(p));
      await tester.tap(find.byKey(const ValueKey('mode-day')));
      await tester.pumpAndSettle();

      crossMidnight();
      // 신호가 아니라 사용자가 직접 당겨서 새로고침합니다.
      await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
      await tester.pumpAndSettle();
      expect(find.text('8월 18일 (화)'), findsOneWidget,
          reason: '새로고침만으로 날을 옮기면 안 됩니다');

      refresh.fire();
      await tester.pumpAndSettle();

      expect(find.text('8월 19일 (수)'), findsOneWidget,
          reason: '새로고침 뒤에 따라가기가 죽었습니다');
    });
  });

  testWidgets('어두운 테마에서도 기록이 있는 화면이 온전히 선다', (tester) async {
    // 화면 전체를 어두운 테마로 띄워 본 적이 없었습니다. 원은 페인터가
    // 그리는데 그 안에는 BuildContext가 없어, 색을 넘기는 연결이 끊기면
    // 여기만 밝은 채로 남습니다.
    await pump(tester, dark: true, loader: (p) async => filled(p));

    expect(tester.takeException(), isNull);
    expect(find.byType(DayRingChip), findsNWidgets(7));
    expect(find.byType(DayRing), findsOneWidget);
    expect(find.text('분유 · 120ml'), findsOneWidget);
  });

  testWidgets('원에 잠이 있는데 목록이 비면 그 까닭을 밝힌다', (tester) async {
    // 자정을 넘는 밤잠은 두 원에 나뉘어 그려지지만, 목록에는 **시작한
    // 날에만** 들어갑니다(RecentRecord.at이 시작 시각). 그래서 원은 여섯
    // 시간을 잤다고 그리는데 바로 아래에서는 남긴 기록이 없다고 말하는
    // 날이 생깁니다. 실제 자료로 재현되던 것입니다.
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    await pump(tester, loader: (p) async => PeriodRecords(sleeps: [
          SleepRecord(
            id: 'n',
            type: SleepType.night,
            startedAt: DateTime(
                yesterday.year, yesterday.month, yesterday.day, 20, 30),
            endedAt: DateTime(today.year, today.month, today.day, 6, 15),
          ),
        ]));

    // 오늘 원에는 새벽 몫이 그려집니다.
    expect(find.textContaining('수면'), findsWidgets);

    // 목록은 비지만, 왜 비는지를 말해야 합니다.
    expect(find.textContaining('이 날 시작한 기록은 없습니다'), findsOneWidget);
    expect(find.text('이 기간에 남긴 기록이 없습니다.'), findsNothing,
        reason: '기간 전체가 넘겨받은 잠뿐일 때도 같은 판단을 써야 합니다');
    expect(find.text('이 날은 남긴 기록이 없습니다.'), findsNothing,
        reason: '원이 잠을 그리는데 아무 기록도 없다고 말하면 서로 다른 말입니다');
  });

  testWidgets('일 눈금에서도 넘겨받은 잠의 까닭을 밝힌다', (tester) async {
    // 일 눈금은 기간이 하루뿐이라, 어제 시작한 잠은 **기간 밖**입니다.
    // 그래서 목록이 _records.isEmpty 쪽으로 빠져나갑니다 — 처음 고칠 때
    // 아래쪽(ofDay) 분기에만 넣어 이 경로가 그대로 어긋나 있었습니다.
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    await pump(tester, loader: (p) async => PeriodRecords(sleeps: [
          SleepRecord(
            id: 'n',
            type: SleepType.night,
            startedAt: DateTime(
                yesterday.year, yesterday.month, yesterday.day, 20, 30),
            endedAt: DateTime(today.year, today.month, today.day, 6, 15),
          ),
        ]));

    await tester.tap(find.byKey(const ValueKey('mode-day')));
    await tester.pumpAndSettle();

    expect(find.textContaining('이 날 시작한 기록은 없습니다'), findsOneWidget);
    expect(find.text('이 기간에 남긴 기록이 없습니다.'), findsNothing,
        reason: '원은 잠을 그리는데 기간에 기록이 없다고만 말하면 어긋납니다');
  });

  testWidgets('정말 아무것도 없는 날은 그냥 없다고 한다', (tester) async {
    // 원도 비었으면 덧붙일 말이 없습니다. 없는 사연을 지어내지 않습니다.
    await pump(tester, loader: (p) async {
      final f = filled(p);
      // 오늘만 비웁니다.
      bool notToday(DateTime at) => !(at.year == today.year &&
          at.month == today.month &&
          at.day == today.day);
      return PeriodRecords(
        feedings: f.feedings.where((r) => notToday(r.fedAt)).toList(),
        diapers: f.diapers.where((r) => notToday(r.recordedAt)).toList(),
        sleeps: f.sleeps
            .where((r) => notToday(r.startedAt) && notToday(r.endedAt!))
            .toList(),
      );
    });

    expect(find.text('이 날은 남긴 기록이 없습니다.'), findsOneWidget);
  });
}
