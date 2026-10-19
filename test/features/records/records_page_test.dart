import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/analysis/analysis_page.dart';
import 'package:flutter_project/features/records/period_records.dart';
import 'package:flutter_project/features/records/record_period.dart';
import 'package:flutter_project/features/records/records_page.dart';

/// Supabase를 초기화하지 않고 띄웁니다.
///
/// 조회는 실패하지만, 그 실패를 화면이 삼키고 안내로 바꾸는지 확인합니다.
/// 서버가 죽었을 때 앱이 빈 화면이 되거나 터지면 안 됩니다.
void main() {
  // 소스를 글로 확인하는 테스트가 두 군데라 위로 올려 둡니다.
  String read(String path) => File(path).readAsStringSync();

  Future<void> pump(WidgetTester tester, Widget page,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('기록 탭', () {
    testWidgets('기록하러 가는 입구를 두지 않는다', (tester) async {
      // 예전에는 여기에도 5칸 격자가 있었는데 홈의 9칸과 겹쳤고, 홈보다
      // 적어서 여기서 기록한다고 배운 사람은 성장·약병원을 찾지 못했습니다.
      await pump(tester, const RecordsPage());

      expect(find.text('무엇을 기록할까요'), findsNothing);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('조회에 실패해도 터지지 않고 안내한다', (tester) async {
      await pump(tester, const RecordsPage());

      expect(tester.takeException(), isNull);
      expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
      await pump(tester, const RecordsPage(), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('기간 조회', () {
    // Supabase가 없어 조회를 돌려 볼 수 없어 글로 확인합니다.
    //
    // 서비스는 최신순으로 정렬해 한도만큼 자르므로, 상한을 주지 않으면 한도가
    // **오늘 쪽부터** 채워집니다. 하루 열 번 기록하는 시기에 지난 기간을 펴면
    // 그 기간 기록이 한 건도 오지 않고, 화면은 그것을 '기록 없음'으로 말합니다.

    test('보고 있는 기간의 끝을 상한으로 준다', () {
      // 조회는 loadPeriodRecords로 옮겨 갔습니다. 여섯 조회 모두에 줍니다 —
      // 성장만 한도 없이 전부 읽으므로 빠집니다.
      final loader = read('lib/features/records/period_records.dart');
      expect(loader.contains('final until = period.end;'), isTrue,
          reason: '기간의 끝을 상한으로 잡지 않습니다');
      expect('until: until'.allMatches(loader).length, 6);
    });

    test('한도는 기간이 길수록 늘어난다', () {
      // 고정값이면 "2026년 8월"이라 적어 놓고 최신 몇 건만 그리게 됩니다.
      final day = RecordPeriod.of(PeriodMode.day, DateTime(2026, 8, 18));
      final week = RecordPeriod.of(PeriodMode.week, DateTime(2026, 8, 18));
      final month = RecordPeriod.of(PeriodMode.month, DateTime(2026, 8, 18));

      expect(windowFor(day), lessThan(windowFor(week)));
      expect(windowFor(week), lessThan(windowFor(month)));
      // 하루 열 번 기록해도 그 기간을 덮어야 합니다.
      expect(windowFor(day), greaterThan(10));
      expect(windowFor(month), greaterThan(31 * 10));
    });

    test('서비스가 상한을 조회에 건다', () {
      const queries = [
        ('lib/features/detail/feeding_record_service.dart', 'fed_at'),
        ('lib/features/detail/diaper_record_service.dart', 'recorded_at'),
        ('lib/features/detail/sleep_record_service.dart', 'started_at'),
        ('lib/features/detail/temperature_record_service.dart', 'measured_at'),
        ('lib/features/detail/care/care_record_service.dart', 'taken_at'),
        ('lib/features/detail/care/care_record_service.dart', 'visited_at'),
      ];
      for (final (path, column) in queries) {
        expect(
          read(path).contains("query.lt('$column', toDbTime(until))"),
          isTrue,
          reason: '$path 가 $column 에 상한을 걸지 않습니다',
        );
      }
    });
  });

  group('자정 따라가기', () {
    // 하단 탭은 IndexedStack이라 화면이 살아 있는 채로 숨겨집니다. 자정을
    // 넘겨 돌아와도 어제에 머물면, 방금 남긴 새벽 기록이 기간 밖으로 걸러져
    // '기록 없음'으로 보입니다.

    test('따라가는 중이면 새 오늘로 옮긴다', () {
      expect(
        dayAfterSignal(
          selectedDay: DateTime(2026, 8, 18),
          followingToday: true,
          now: DateTime(2026, 8, 19, 0, 5),
        ),
        DateTime(2026, 8, 19),
      );
    });

    test('지난 날을 펴 둔 사람은 끌어오지 않는다', () {
      expect(
        dayAfterSignal(
          selectedDay: DateTime(2026, 8, 10),
          followingToday: false,
          now: DateTime(2026, 8, 19, 0, 5),
        ),
        DateTime(2026, 8, 10),
      );
    });

    test('날이 그대로면 보던 날 그대로다', () {
      expect(
        dayAfterSignal(
          selectedDay: DateTime(2026, 8, 18),
          followingToday: true,
          now: DateTime(2026, 8, 18, 23, 50),
        ),
        DateTime(2026, 8, 18),
      );
    });

    test('신호 처리가 판정 함수에 진짜 상태를 넘긴다', () {
      // 판정 자체는 위 세 테스트가 봅니다. 정작 이번 결함은 판정이 아니라
      // **배선**에서 났습니다 — 기준점을 조회 시각으로 재는 바람에, 오늘을
      // 보고 있던 사람이 당겨서 새로고침 한 번에 어제로 갇혔습니다.
      // 상수를 넘겨도 순수 함수 테스트는 전부 초록이라 여기서 봅니다.
      final page = read('lib/features/records/records_page.dart');
      final call = page.indexOf('dayAfterSignal(');
      expect(call, isNonNegative, reason: '_onSignal이 판정 함수를 부르지 않습니다');

      final args = page.substring(call, page.indexOf(');', call));
      expect(args.contains('followingToday: _followingToday'), isTrue,
          reason: '따라가는 중인지를 상태에서 읽어 넘겨야 합니다');
      expect(args.contains('selectedDay: _selectedDay'), isTrue);
    });

    test('조회는 따라가기 기준점을 건드리지 않는다', () {
      // 예전에는 조회 시각으로 판단했는데, 조회는 신호 말고도 당겨서
      // 새로고침·눈금 변경·'다시 시도'가 부릅니다. 자정 뒤에 그중 하나가
      // 먼저 돌면 오늘 따라가기가 영영 풀렸습니다.
      final page = File('lib/features/records/records_page.dart')
          .readAsStringSync();
      final load = page.substring(
        page.indexOf('Future<void> _load() async {'),
        page.indexOf('void _changeMode('),
      );
      expect(load.contains('_followingToday'), isFalse,
          reason: '조회가 따라가기 상태를 바꾸면 안 됩니다');
    });
  });

  group('아이가 없을 때', () {
    testWidgets('기록 탭이 등록으로 가는 길을 준다', (tester) async {
      // 안내만 하고 갈 길을 주지 않으면 막다른 길입니다. 시키는 대로
      // 등록하려 해도 이 화면에서는 갈 수 없었습니다.
      await pump(tester, RecordsPage(loader: (p) async => PeriodRecords.noBaby));

      expect(find.text('아이 정보를 먼저 등록해 주세요.'), findsOneWidget);
      expect(find.text('등록하기'), findsOneWidget,
          reason: '갈 길이 없으면 안내가 막다른 길이 됩니다');
    });

    testWidgets('실패는 여전히 실패라고 말한다', (tester) async {
      // 등록 단추를 붙이면서 실패 안내를 덮으면 안 됩니다.
      await pump(tester, RecordsPage(loader: (p) async => throw StateError('끊김')));

      expect(find.text('기록을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('등록하기'), findsNothing,
          reason: '조회 실패는 아이 미등록이 아닙니다');
    });
  });

  group('분석 탭', () {
    testWidgets('조회에 실패해도 터지지 않고 안내한다', (tester) async {
      await pump(tester, const AnalysisPage());

      expect(tester.takeException(), isNull);
      expect(find.text('분석을 불러오지 못했습니다.'), findsOneWidget);
    });

    testWidgets('글자를 키워도 넘치지 않는다', (tester) async {
      await pump(tester, const AnalysisPage(), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
