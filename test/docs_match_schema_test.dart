import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 문서에 적힌 숫자가 실제와 맞는지 확인합니다.
///
/// 한때 테이블 수가 문서 네 곳에서 14 · 16 · 18 · 20으로 제각각이었습니다.
/// 손으로 세는 한 또 벌어지므로, 세는 일을 여기에 맡깁니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// `create table [if not exists] public.<이름>` 을 전부 셉니다.
  Set<String> tablesIn(String sql) => RegExp(
        r'create table (?:if not exists )?public\.(\w+)',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(1)!).toSet();

  final schema = read('supabase/schema.sql');
  final schemaTables = tablesIn(schema);

  final migrationTables = <String>{
    for (final f in Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql')))
      ...tablesIn(f.readAsStringSync()),
  };

  test('schema.sql 하나로 모든 표를 만들 수 있다', () {
    // README는 새 DB를 만들 때 schema.sql만 실행하라고 안내합니다.
    // 마이그레이션에만 있는 표가 생기면 그 안내가 거짓이 됩니다.
    final missing = migrationTables.difference(schemaTables).toList()..sort();

    expect(missing, isEmpty,
        reason: '이 표들이 schema.sql에 없어 새 DB에서 빠집니다: ${missing.join(', ')}');
  });

  test('문서에 적힌 테이블 수가 실제와 같다', () {
    final actual = schemaTables.length;

    final claims = <String, RegExp>{
      'docs/thesis-db-section.md': RegExp(r'전체 스키마는 (\d+)개 테이블'),
      'docs/supabase-todo.md': RegExp(r'테이블 \*\*(\d+)개\*\* 중'),
    };

    claims.forEach((path, pattern) {
      final match = pattern.firstMatch(read(path));
      expect(match, isNotNull, reason: '$path 에서 테이블 수 서술을 찾지 못했습니다');
      expect(int.parse(match!.group(1)!), actual, reason: path);
    });
  });

  test('owns_baby를 경유하는 정책 수가 문서와 같다', () {
    // 함께 키우기의 핵심 주장입니다 — "함수 하나만 바꾸면 정책 N개가 따라온다".
    // 이 숫자가 틀리면 논문의 설계 근거도 함께 틀립니다.
    final policies = RegExp(
      r'create policy .*?;',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(schema).map((m) => m.group(0)!);

    final viaOwnership = policies
        .where((p) =>
            p.contains('owns_baby') ||
            p.contains('owns_sleep_record') ||
            p.contains('owns_temp_record'))
        .length;

    for (final path in ['README.md', 'docs/supabase-todo.md']) {
      final claimed = RegExp(r'정책 (\d+)개').allMatches(read(path));
      for (final m in claimed) {
        expect(int.parse(m.group(1)!), viaOwnership, reason: path);
      }
    }
  });
}
