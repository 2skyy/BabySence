import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/core/services/baby_service.dart';
import 'package:flutter_project/core/services/growth_calculator.dart';
import 'package:flutter_project/features/detail/growth/growth_record.dart';
import 'package:flutter_project/features/detail/growth/growth_record_page.dart';
import 'package:flutter_project/features/detail/growth/growth_repository.dart';

/// Supabase 없이 화면만 검증하기 위한 가짜 저장소.
class _FakeGrowthRepository implements GrowthRepository {
  _FakeGrowthRepository({this.baby, List<GrowthRecord>? records, this.throwOnLoad = false})
      : records = records ?? [];

  Baby? baby;
  List<GrowthRecord> records;
  bool throwOnLoad;

  final List<Map<String, dynamic>> savedCalls = [];
  final List<String> deletedIds = [];

  @override
  Future<Baby?> loadBaby() async {
    if (throwOnLoad) throw Exception('네트워크 오류');
    return baby;
  }

  @override
  Future<List<GrowthRecord>> loadRecords(String babyId) async => records;

  @override
  Future<void> saveRecord({
    required String babyId,
    required DateTime date,
    double? heightCm,
    double? weightKg,
  }) async {
    savedCalls.add({
      'babyId': babyId,
      'date': date,
      'heightCm': heightCm,
      'weightKg': weightKg,
    });
    // 저장 후 _load()가 다시 읽어가므로, 실제 DB처럼 목록에도 반영합니다.
    records = [
      ...records,
      GrowthRecord(
        id: 'r${records.length + 1}',
        date: date,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    ];
  }

  @override
  Future<void> deleteRecord(String id) async {
    deletedIds.add(id);
    records = records.where((r) => r.id != id).toList();
  }
}

final _baby = Baby(
  id: 'baby-1',
  name: '아기',
  sex: ChildSex.male,
  birthDate: DateTime(2026, 1, 1),
);

Widget _wrap(GrowthRepository repository) => MaterialApp(
      home: GrowthRecordPage(repository: repository),
    );

void main() {
  testWidgets('아이가 없으면 온보딩으로 보내는 안내를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeGrowthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('아이 정보 등록하기'), findsOneWidget);
    // 등록 폼은 온보딩 화면 한 곳에만 있어야 합니다.
    expect(find.text('기록 추가'), findsNothing);
  });

  testWidgets('아이가 있으면 기록 입력 폼과 이력을 보여준다', (tester) async {
    final repo = _FakeGrowthRepository(
      baby: _baby,
      records: [
        GrowthRecord(
          id: 'r1',
          date: DateTime(2026, 3, 1),
          heightCm: 60.0,
          weightKg: 5.5,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('기록 추가'), findsOneWidget);
    expect(find.text('기록 이력'), findsOneWidget);
    expect(find.textContaining('키 60.0cm'), findsOneWidget);
    expect(find.textContaining('몸무게 5.5kg'), findsOneWidget);
  });

  testWidgets('기록을 추가하면 저장소에 전달되고 이력에 나타난다', (tester) async {
    final repo = _FakeGrowthRepository(baby: _baby);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '키 (cm)'), '62');
    await tester.enterText(find.widgetWithText(TextField, '몸무게 (kg)'), '6.2');
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();

    expect(repo.savedCalls, hasLength(1));
    expect(repo.savedCalls.single['babyId'], 'baby-1');
    expect(repo.savedCalls.single['heightCm'], 62.0);
    expect(repo.savedCalls.single['weightKg'], 6.2);

    expect(find.textContaining('키 62.0cm'), findsOneWidget);
  });

  testWidgets('키와 몸무게가 모두 비어 있으면 저장하지 않는다', (tester) async {
    final repo = _FakeGrowthRepository(baby: _baby);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();

    expect(repo.savedCalls, isEmpty);
    expect(find.text('키 또는 몸무게 중 하나는 입력해주세요.'), findsOneWidget);
  });

  testWidgets('삭제 버튼을 누르면 저장소에서 지우고 목록에서 사라진다', (tester) async {
    final repo = _FakeGrowthRepository(
      baby: _baby,
      records: [
        GrowthRecord(id: 'r1', date: DateTime(2026, 3, 1), weightKg: 5.5),
      ],
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // 기록 이력은 차트 아래에 있어 기본 테스트 뷰포트(800x600) 밖입니다.
    // 스크롤해서 노출시키지 않으면 탭이 빈 곳에 떨어집니다.
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // 곧바로 지우지 않고 한 번 묻습니다. 이 기록은 되돌릴 수 없습니다.
    expect(find.text('이 기록을 지울까요?'), findsOneWidget);
    expect(repo.deletedIds, isEmpty, reason: '묻기 전에 지우면 안 됩니다');

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, ['r1']);
    expect(find.textContaining('몸무게 5.5kg'), findsNothing);
  });

  testWidgets('삭제 확인 창에서 취소하면 지우지 않는다', (tester) async {
    final repo = _FakeGrowthRepository(
      baby: _baby,
      records: [
        GrowthRecord(id: 'r1', date: DateTime(2026, 3, 1), weightKg: 5.5),
      ],
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, isEmpty);
    expect(find.textContaining('몸무게 5.5kg'), findsOneWidget);
  });

  testWidgets('불러오기가 실패하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final repo = _FakeGrowthRepository(throwOnLoad: true);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('데이터를 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    // 원인이 해소된 뒤 다시 시도하면 정상 화면으로 넘어갑니다.
    repo.throwOnLoad = false;
    repo.baby = _baby;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('기록 추가'), findsOneWidget);
  });
}
