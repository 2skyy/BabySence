import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/care/care_record_service.dart';

/// 논문 3-2절 ⑥ "약 복용 정보와 병원 방문 기록을 저장하고, 이를 기반으로
/// 반복적인 증상 발생 여부를 확인한다."
void main() {
  final now = DateTime(2026, 8, 12, 10, 0);

  MedicationRecord med(MedicationReason reason, {int daysAgo = 0}) =>
      MedicationRecord(
        id: 'm$daysAgo${reason.name}',
        name: '해열시럽',
        reason: reason,
        takenAt: now.subtract(Duration(days: daysAgo)),
      );

  HospitalVisit visit(VisitReason reason, {int daysAgo = 0}) => HospitalVisit(
        id: 'v$daysAgo${reason.name}',
        reason: reason,
        visitedAt: now.subtract(Duration(days: daysAgo)),
      );

  List<ReasonCount> countOf({
    List<MedicationRecord> medications = const [],
    List<HospitalVisit> visits = const [],
  }) =>
      repeatedReasons(medications: medications, visits: visits, now: now);

  group('DB 값과 enum', () {
    test('CHECK 제약과 같은 값을 보낸다', () {
      // 이름이 어긋나면 저장이 통째로 실패합니다.
      expect(MedicationReason.runnyNose.dbValue, 'runny_nose');
      expect(MedicationReason.fever.dbValue, 'fever');
      expect(VisitReason.runnyNose.dbValue, 'runny_nose');
      expect(VisitReason.vaccination.dbValue, 'vaccination');
    });

    test('모르는 값은 기타로 읽는다', () {
      // 나중에 CHECK에 항목이 늘어도 조회가 깨지지 않아야 합니다.
      expect(MedicationReason.fromDbValue('없는값'), MedicationReason.other);
      expect(VisitReason.fromDbValue(null), VisitReason.other);
    });
  });

  group('저장할 행', () {
    test('빈 용량은 빈 문자열이 아니라 null로 넣는다', () {
      // 빈 문자열은 "0ml을 먹였다"처럼 읽힙니다.
      final row = CareRecordService.buildMedicationRow(
        babyId: 'baby-1',
        name: '해열시럽',
        reason: MedicationReason.fever,
        takenAt: now,
        dose: '   ',
      );

      expect(row['dose'], isNull);
    });

    test('앞뒤 공백을 지운다', () {
      // CHECK가 trim한 길이를 보므로, 공백만 넣으면 DB가 거부합니다.
      final row = CareRecordService.buildMedicationRow(
        babyId: 'baby-1',
        name: '  해열시럽  ',
        reason: MedicationReason.fever,
        takenAt: now,
      );

      expect(row['name'], '해열시럽');
    });

    test('병원 이름과 메모도 비어 있으면 null', () {
      final row = CareRecordService.buildVisitRow(
        babyId: 'baby-1',
        reason: VisitReason.checkup,
        visitedAt: now,
        hospitalName: '',
        note: null,
      );

      expect(row['hospital_name'], isNull);
      expect(row['note'], isNull);
      expect(row['reason'], 'checkup');
    });
  });

  group('반복된 이유 세기', () {
    test('한 번뿐이면 반복이 아니다', () {
      expect(countOf(medications: [med(MedicationReason.fever)]), isEmpty);
    });

    test('두 번부터 센다', () {
      final counts = countOf(medications: [
        med(MedicationReason.fever, daysAgo: 1),
        med(MedicationReason.fever, daysAgo: 10),
      ]);

      expect(counts, hasLength(1));
      expect(counts.first.label, '발열');
      expect(counts.first.count, 2);
    });

    test('투약과 병원 방문을 함께 센다', () {
      // 같은 증상으로 약을 먹이고 병원에도 갔다면 두 번입니다.
      final counts = countOf(
        medications: [med(MedicationReason.vomit, daysAgo: 2)],
        visits: [visit(VisitReason.vomit, daysAgo: 3)],
      );

      expect(counts.single.label, '구토');
      expect(counts.single.count, 2);
    });

    test('기간을 벗어난 기록은 빼고 센다', () {
      final counts = countOf(medications: [
        med(MedicationReason.cough, daysAgo: 5),
        med(MedicationReason.cough, daysAgo: 200),
      ]);

      expect(counts, isEmpty, reason: '기간 안에는 한 번뿐입니다');
    });

    test('정기검진과 예방접종은 세지 않는다', () {
      // 아파서 간 것이 아닙니다. 넣으면 검진 일정 때문에 '반복'이 늘어납니다.
      final counts = countOf(visits: [
        visit(VisitReason.checkup, daysAgo: 1),
        visit(VisitReason.checkup, daysAgo: 30),
        visit(VisitReason.vaccination, daysAgo: 2),
        visit(VisitReason.vaccination, daysAgo: 40),
      ]);

      expect(counts, isEmpty);
    });

    test('처방약과 기타는 세지 않는다', () {
      // 어떤 증상인지 알 수 없어 반복의 근거가 되지 못합니다.
      final counts = countOf(medications: [
        med(MedicationReason.prescription, daysAgo: 1),
        med(MedicationReason.prescription, daysAgo: 2),
        med(MedicationReason.other, daysAgo: 3),
        med(MedicationReason.other, daysAgo: 4),
      ]);

      expect(counts, isEmpty);
    });

    test('많은 순으로 보여준다', () {
      final counts = countOf(medications: [
        med(MedicationReason.cough, daysAgo: 1),
        med(MedicationReason.cough, daysAgo: 2),
        med(MedicationReason.fever, daysAgo: 3),
        med(MedicationReason.fever, daysAgo: 4),
        med(MedicationReason.fever, daysAgo: 5),
      ]);

      expect(counts.map((c) => c.label), ['발열', '기침']);
    });

    test('횟수가 같으면 이름순으로 고정된다', () {
      // 열 때마다 순서가 바뀌면 읽기 어렵습니다.
      final counts = countOf(medications: [
        med(MedicationReason.vomit, daysAgo: 1),
        med(MedicationReason.vomit, daysAgo: 2),
        med(MedicationReason.cough, daysAgo: 3),
        med(MedicationReason.cough, daysAgo: 4),
      ]);

      expect(counts.map((c) => c.count), [2, 2]);
      expect(counts.map((c) => c.label).toList()..sort(),
          counts.map((c) => c.label).toList());
    });

    test('기록이 없으면 빈 목록', () {
      expect(countOf(), isEmpty);
    });
  });

  group('이력 요약', () {
    test('용량이 있으면 함께 보여준다', () {
      expect(
        MedicationRecord(
          id: 'm1',
          name: '해열시럽',
          dose: '5ml',
          reason: MedicationReason.fever,
          takenAt: now,
        ).summary,
        '해열시럽 5ml · 발열',
      );
    });

    test('용량이 없으면 약 이름과 이유만', () {
      expect(
        MedicationRecord(
          id: 'm2',
          name: '항생제',
          reason: MedicationReason.prescription,
          takenAt: now,
        ).summary,
        '항생제 · 처방약',
      );
    });

    test('병원 이름이 없으면 이유만 보여준다', () {
      expect(
        HospitalVisit(
          id: 'v1',
          reason: VisitReason.checkup,
          visitedAt: now,
        ).summary,
        '정기검진',
      );
    });

    test('메모는 줄을 바꿔 붙인다', () {
      expect(
        HospitalVisit(
          id: 'v2',
          hospitalName: '우리소아과',
          reason: VisitReason.vomit,
          note: '수분 섭취를 지켜보라고 하심',
          visitedAt: now,
        ).summary,
        '우리소아과 · 구토\n수분 섭취를 지켜보라고 하심',
      );
    });
  });
}
