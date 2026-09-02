import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/diaper_record_service.dart';
import 'package:flutter_project/features/detail/feeding_record_service.dart';

/// 화면이 기록 종류 이름을 **문자열로 다시 적으면** enum과 어긋날 수 있고,
/// `fromLabel`은 `orElse`로 조용히 기본값을 돌려줍니다 — 대변이 소변으로,
/// 모유가 분유로 저장됩니다. 화면이 깨지지도, 오류가 뜨지도 않습니다.
///
/// 그래서 화면은 `X.값.label`로 이름을 가져와야 합니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('배변 화면에 종류 이름이 문자열로 박혀 있지 않다', () {
    final s = read('lib/features/detail/diaper_record_page.dart');
    for (final e in DiaperType.values) {
      expect(s, isNot(contains("'${e.label}'")),
          reason: "'${e.label}'을 DiaperType.${e.name}.label로 바꾸세요");
      expect(s, isNot(contains('"${e.label}"')),
          reason: '"${e.label}"을 DiaperType.${e.name}.label로 바꾸세요');
    }
    for (final e in StoolState.values) {
      expect(s, isNot(contains("'${e.label}'")), reason: e.label);
      expect(s, isNot(contains('"${e.label}"')), reason: e.label);
    }
  });

  test('수유 화면에 종류 이름이 문자열로 박혀 있지 않다', () {
    final s = read('lib/features/detail/feeding_record_page.dart');
    for (final e in FeedingType.values) {
      expect(s, isNot(contains("'${e.label}'")),
          reason: "'${e.label}'을 FeedingType.${e.name}.label로 바꾸세요");
      expect(s, isNot(contains('"${e.label}"')), reason: e.label);
    }
  });

  test('되돌리기가 모든 이름에서 성립한다', () {
    for (final e in DiaperType.values) {
      expect(DiaperType.fromLabel(e.label), e);
    }
    for (final e in StoolState.values) {
      expect(StoolState.fromLabel(e.label), e);
    }
    for (final e in FeedingType.values) {
      expect(FeedingType.fromLabel(e.label), e);
    }
  });
}
