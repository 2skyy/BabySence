import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/detail/care/care_record_service.dart';
import 'package:flutter_project/features/detail/temperature_record_service.dart';
import 'package:flutter_project/features/detail/vaccination_readiness.dart';

/// 논문 3-2절 ⑦ "접종 가능 여부를 판단한다"에 대한 구현입니다.
///
/// **판정하지 않기로 한 것이 핵심입니다.** 세 기관의 지침이 모두 체온으로
/// 접종 가부를 가르지 말라고 합니다.
/// - CDC/ACIP: "ACIP has not defined a body temperature above which vaccines
///   should not be administered."
/// - 질병관리청: 주의사항은 "중등도 또는 중증의 급성 질환(발열 여부에 무관)"
/// - WHO: "a fever below 38.5 ℃, vaccinate as usual"
void main() {
  final now = DateTime(2026, 8, 12, 10, 0);

  TemperatureRecord temp(double c, {int daysAgo = 0, List<Symptom> symptoms = const []}) =>
      TemperatureRecord(
        id: 't$daysAgo$c',
        temperatureC: c,
        measuredAt: now.subtract(Duration(days: daysAgo)),
        symptoms: symptoms,
      );

  MedicationRecord med(String name, {int daysAgo = 0}) => MedicationRecord(
        id: 'm$daysAgo$name',
        name: name,
        reason: MedicationReason.fever,
        takenAt: now.subtract(Duration(days: daysAgo)),
      );

  HospitalVisit visit(VisitReason reason, {int daysAgo = 0}) => HospitalVisit(
        id: 'v$daysAgo${reason.name}',
        reason: reason,
        visitedAt: now.subtract(Duration(days: daysAgo)),
      );

  VaccinationReadiness build({
    List<TemperatureRecord> temperatures = const [],
    List<MedicationRecord> medications = const [],
    List<HospitalVisit> visits = const [],
  }) =>
      buildReadiness(
        temperatures: temperatures,
        medications: medications,
        visits: visits,
        now: now,
      );

  group('판정하지 않는다', () {
    test('어떤 체온에도 가부를 내지 않는다', () {
      // 40℃여도 '접종 불가'라고 하지 않습니다. 그 판단은 진찰의 몫입니다.
      // API에 그런 값을 돌려줄 자리가 아예 없다는 것을 고정합니다.
      final r = build(temperatures: [temp(40.0)]);

      expect(r.notes, hasLength(1));
      expect(r.notes.single.text, contains('40.0℃'));
      // 결과 타입에 '가능/불가' 같은 필드가 없어야 합니다.
      expect(r.hasNotes, isTrue);
    });

    test('기록이 없어도 괜찮다고 말하지 않는다', () {
      // 빈 목록은 '앱이 아는 것이 없다'는 뜻이지 '접종해도 된다'가 아닙니다.
      expect(build().hasNotes, isFalse);
    });
  });

  group('무엇을 모으는가', () {
    test('정상 범위 체온은 넣지 않는다', () {
      // 전부 늘어놓으면 정작 볼 것이 묻힙니다.
      expect(build(temperatures: [temp(36.8), temp(37.5)]).notes, isEmpty);
    });

    test('정상 범위를 벗어난 체온만 넣는다', () {
      final r = build(temperatures: [temp(38.2), temp(36.0), temp(37.0)]);

      expect(r.notes, hasLength(2));
      expect(r.notes.map((n) => n.text).join(), contains('38.2℃'));
      expect(r.notes.map((n) => n.text).join(), contains('36.0℃'));
    });

    test('동반 증상을 함께 적는다', () {
      final r = build(temperatures: [
        temp(38.2, symptoms: [Symptom.cough, Symptom.vomit])
      ]);

      expect(r.notes.single.text, contains('기침'));
      expect(r.notes.single.text, contains('구토'));
    });

    test('약과 병원 방문도 모은다', () {
      final r = build(
        medications: [med('해열시럽')],
        visits: [visit(VisitReason.cough)],
      );

      expect(r.notes.map((n) => n.text), contains('해열시럽 복용'));
      expect(r.notes.map((n) => n.text), contains('병원 방문 · 기침'));
    });

    test('접종하러 간 방문은 빼고 본다', () {
      // 접종 전 확인 사항이 아닙니다.
      expect(build(visits: [visit(VisitReason.vaccination)]).notes, isEmpty);
    });

    test('정기검진은 넣는다', () {
      // 그날 무슨 얘기를 들었는지 진료실에서 말할 수 있습니다.
      expect(build(visits: [visit(VisitReason.checkup)]).notes, hasLength(1));
    });
  });

  group('기간', () {
    test('$readinessWindowDays일이 지난 기록은 빼고 본다', () {
      expect(
        build(temperatures: [temp(38.5, daysAgo: readinessWindowDays + 1)]).notes,
        isEmpty,
      );
    });

    test('기간 안의 기록은 넣는다', () {
      expect(
        build(temperatures: [temp(38.5, daysAgo: readinessWindowDays - 1)]).notes,
        hasLength(1),
      );
    });

    test('최신순으로 보여준다', () {
      final r = build(
        temperatures: [temp(38.2, daysAgo: 2)],
        medications: [med('해열시럽')],
      );

      expect(r.notes.first.text, '해열시럽 복용');
    });
  });

  group('미루지 않아도 되는 것 안내', () {
    test('질병관리청이 금기가 아니라고 밝힌 것들을 담는다', () {
      // 세 지침 모두 불필요한 연기를 더 크게 경계합니다.
      final joined = notContraindications.join(' ');

      expect(joined, contains('미열'));
      expect(joined, contains('중이염'));
      expect(joined, contains('항생제'));
      expect(joined, contains('미숙아'));
    });

    test('목록이 비어 있지 않다', () {
      expect(notContraindications, isNotEmpty);
    });
  });
}
