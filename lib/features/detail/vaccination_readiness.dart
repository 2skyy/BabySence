/// 접종 전에 보호자가 확인할 것들.
///
/// ## 판정하지 않습니다 — 그렇게 만들면 안 되기 때문입니다
///
/// 논문 3-2절 ⑦은 "접종 가능 여부를 판단한다"고 썼지만, **체온으로 접종
/// 가능/불가를 가르는 규칙은 만들 수 없습니다.** 세 기관의 지침이 모두
/// 그렇게 하지 말라고 명시합니다.
///
/// - **CDC/ACIP**: "ACIP has not defined a body temperature above which
///   vaccines should not be administered." / "Measuring temperature is not
///   necessary before vaccination if the patient does not appear ill."
///   ([1] General Best Practice Guidelines for Immunization)
/// - **질병관리청**: 접종 주의사항은 "중등도 또는 중증의(moderate or severe)
///   급성 질환(**발열 여부에 무관**)"입니다. 괄호가 핵심입니다 — 열이 있고
///   없고가 기준이 아닙니다. ([2] 2026년 국가예방접종 지침)
/// - **WHO**: "For children with a minor illness and/or a fever below
///   38.5 °C, vaccinate as usual." 심지어 "children who have a very high
///   fever, vaccinate if possible"입니다. ([3] Immunization in practice, 2025)
///
/// 실제 기준인 "중등도~중증 급성 질환"은 **진찰로 가리는 것**이라 이 앱이
/// 계산할 수 없습니다. 그래서 판정 대신 **기록을 모아 보여주기만** 합니다.
/// 질병관리청 예진표의 3번 문항 "오늘 아픈 곳이 있습니까?"에 보호자가 정확히
/// 답할 수 있게 돕는 것이 이 화면이 할 수 있는 전부이자 최선입니다.
///
/// ## 미루지 말라는 쪽이 더 중요합니다
///
/// 세 지침 모두 **불필요한 연기**를 경계합니다.
/// - CDC: "failure to vaccinate children with minor illnesses can impede
///   vaccination efforts" / "missed opportunities to administer recommended
///   vaccines"
/// - WHO: "delaying immunization puts them at risk of vaccine-preventable
///   diseases when they could receive the protection safely"
/// - 질병관리청: "경한 급성 질환(미열, 감기, 상기도 감염, 중이염 및 경미한
///   설사)"은 금기사항이 아닙니다.
///
/// 그래서 이 화면은 "미루세요"가 아니라 **"이 정도로는 미루지 않아도
/// 됩니다"** 를 함께 알려줍니다.
///
/// 출처
/// - [1] Centers for Disease Control and Prevention. *General Best Practice
///   Guidelines for Immunization: Best Practices Guidance of the Advisory
///   Committee on Immunization Practices (ACIP)*. Atlanta, GA: CDC.
/// - [2] 질병관리청. *2026년 국가예방접종 지침(의료기관용)*. 「접종 금기 및
///   주의사항」.
/// - [3] World Health Organization. *Immunization in practice: a guide for
///   health workers*. Geneva: WHO, 2025. Module 5 §3.2.1.
library;

import 'assessment/temperature_rules.dart';
import 'care/care_record_service.dart';
import 'temperature_record_service.dart';

/// 접종 전에 진료실에서 말할 만한 기록 한 줄.
class ReadinessNote {
  /// 화면에 보여줄 문장.
  final String text;

  /// 언제 있었던 일인지.
  final DateTime at;

  const ReadinessNote({required this.text, required this.at});
}

/// 접종 전 확인 정보.
///
/// [notes]가 비어 있어도 "괜찮다"는 뜻이 아닙니다. 앱이 아는 범위에서
/// 최근에 적어 둔 것이 없다는 뜻일 뿐입니다.
class VaccinationReadiness {
  /// 진료실에서 말할 만한 최근 기록들. 최신순입니다.
  final List<ReadinessNote> notes;

  const VaccinationReadiness({required this.notes});

  bool get hasNotes => notes.isNotEmpty;
}

/// 최근 며칠까지 거슬러 볼지.
///
/// 예진표가 묻는 것은 "**오늘** 아픈 곳"이지만, 며칠 전 열이 났다가 내린
/// 경과도 진료실에서 말할 가치가 있습니다. 너무 길게 잡으면 지난달 감기까지
/// 끌어와 시끄러워집니다.
const int readinessWindowDays = 3;

/// 질병관리청이 "금기사항이 아니다"라고 명시한 것들.
///
/// 원문: "일반적으로 다음의 경우는 예방접종 금기사항이 아닙니다. 예진 후
/// 접종하시기 바랍니다. •경한 급성 질환(미열, 감기, 상기도 감염, 중이염 및
/// 경미한 설사)" — [2] 질병관리청 예방접종도우미.
const List<String> notContraindications = [
  '미열, 감기, 상기도 감염, 중이염, 경미한 설사',
  '항생제를 먹는 중',
  '미숙아·저체중으로 태어난 경우',
  '알레르기나 천식 (백신 성분 알레르기는 제외)',
  '가족 중에 경련·이상반응 이력이 있는 경우',
];

/// 최근 기록을 접종 전 확인 목록으로 모읍니다.
///
/// **판정하지 않습니다.** 어떤 값도 '접종 가능/불가'로 바꾸지 않습니다.
/// 보호자가 예진표에 정확히 답할 수 있도록 자기 기록을 되짚어 줄 뿐입니다.
///
/// [now]를 받는 이유는 테스트에서 시간을 고정하기 위해서입니다.
VaccinationReadiness buildReadiness({
  required List<TemperatureRecord> temperatures,
  required List<MedicationRecord> medications,
  required List<HospitalVisit> visits,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final since = at.subtract(const Duration(days: readinessWindowDays));

  final notes = <ReadinessNote>[];

  for (final t in temperatures) {
    if (t.measuredAt.isBefore(since)) continue;
    // 정상 범위는 적지 않습니다. 전부 늘어놓으면 정작 볼 것이 묻힙니다.
    if (t.temperatureC >= TemperatureRules.normalLow &&
        t.temperatureC <= TemperatureRules.normalHigh) {
      continue;
    }
    final symptoms = t.symptoms.map((s) => s.label).join(', ');
    notes.add(ReadinessNote(
      text: symptoms.isEmpty
          ? '체온 ${t.temperatureC.toStringAsFixed(1)}℃'
          : '체온 ${t.temperatureC.toStringAsFixed(1)}℃ · $symptoms',
      at: t.measuredAt,
    ));
  }

  for (final m in medications) {
    if (m.takenAt.isBefore(since)) continue;
    notes.add(ReadinessNote(text: '${m.name} 복용', at: m.takenAt));
  }

  for (final v in visits) {
    if (v.visitedAt.isBefore(since)) continue;
    // 접종하러 간 방문은 접종 전 확인 사항이 아닙니다.
    if (v.reason == VisitReason.vaccination) continue;
    notes.add(ReadinessNote(
      text: '병원 방문 · ${v.reason.label}',
      at: v.visitedAt,
    ));
  }

  notes.sort((a, b) => b.at.compareTo(a.at));
  return VaccinationReadiness(notes: notes);
}
