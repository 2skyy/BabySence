import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/vaccination_service.dart';

/// "최근 N일"이라고 적어 두고 실제로는 최신 20건만 보던 문제를 막습니다.
///
/// 기간을 말하는 화면은 조회에 `since`를 넘겨야 합니다. 기본 limit에만
/// 기대면 그 창 안의 옛 기록이 통째로 빠집니다 — 열이 나서 자주 잰
/// 아이일수록 첫날 고열이 사라지는데, 하필 가장 알고 싶은 값입니다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('기간을 말하는 화면은 창 전체를 읽는다', () {
    test('약·병원 반복 카드 — 90일', () {
      final page =
          read('lib/features/detail/care/care_record_page.dart');
      expect(page.contains('repeatWindowDays'), isTrue,
          reason: '반복 창과 같은 기간을 조회에 넘기세요');
      expect(page.contains('since: since'), isTrue);
    });

    test('접종 전 확인 — 3일', () {
      final page = read('lib/features/detail/vaccination_page.dart');
      expect(page.contains('readinessWindowDays'), isTrue);
      expect(page.contains('since: since'), isTrue);
    });

    test('서비스 셋이 since를 받는다', () {
      for (final path in [
        'lib/features/detail/temperature_record_service.dart',
        'lib/features/detail/care/care_record_service.dart',
      ]) {
        expect(read(path).contains('DateTime? since'), isTrue, reason: path);
        expect(read(path).contains('.gte('), isTrue, reason: path);
      }
    });
  });

  group('접종 예정일이 지났는지', () {
    final vaccine = Vaccine(
      id: 1,
      code: 'bcg',
      name: 'BCG',
      recommendedAgeLabel: '생후 4주 이내',
      recommendedAgeMonths: 0,
      doseNumber: 1,
    );

    VaccinationStatus at(DateTime scheduled) =>
        VaccinationStatus(vaccine: vaccine, scheduledOn: scheduled);

    test('접종일 당일은 지난 것이 아니다', () {
      // scheduledOn은 자정, now는 현재 시각입니다. 그대로 견주면 당일
      // 오전부터 '지남'이 되어, 같은 화면의 'D-day 오늘'과 부딪힙니다.
      final today = DateTime(2026, 8, 12);
      expect(at(today).isOverdue(DateTime(2026, 8, 12, 9, 30)), isFalse);
      expect(at(today).isOverdue(DateTime(2026, 8, 12, 23, 59)), isFalse);
    });

    test('어제 예정이면 지난 것이다', () {
      expect(
        at(DateTime(2026, 8, 11)).isOverdue(DateTime(2026, 8, 12, 0, 1)),
        isTrue,
      );
    });

    test('이미 맞았으면 지난 것이 아니다', () {
      final done = VaccinationStatus(
        vaccine: vaccine,
        scheduledOn: DateTime(2026, 8, 1),
        vaccinatedOn: DateTime(2026, 8, 2),
      );
      expect(done.isOverdue(DateTime(2026, 8, 12)), isFalse);
    });
  });
}
