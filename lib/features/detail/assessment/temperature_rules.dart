import '../temperature_record_service.dart' show Symptom;
import 'assessment.dart';

/// 연령대별 체온 판단 기준.
///
/// 기준표(<표 3> 연령대별 체온 판단 기준)
///
/// | 연령      | 정상        | 주의        | 상담 권장            |
/// |-----------|-------------|-------------|----------------------|
/// | 0~3개월   | 36.5~37.5℃ | 37.5~38.0℃ | 38.0℃ 이상 (즉시 병원) |
/// | 3~6개월   | 36.5~37.5℃ | 37.5~38.5℃ | 38.5℃ 이상           |
/// | 6개월 이상 | 36.5~37.5℃ | 38.0~39.0℃ | 39.0℃ 이상           |
///
/// **출처 주의**: [25] 대한소아과학회 소아 발열 질환정보를 확인한 결과, 위 표의
/// 연령별 구분(38.0/38.5/39.0℃)은 그 문서에서 확인되지 않았습니다. 문서에는 연령
/// 구분 없이 겨드랑이 37.3℃ 이상=미열, 38.0℃ 이상=병원 권고, 39.0℃ 이상=고열로
/// 되어 있습니다. 논문에서 이 표를 인용할 때는 실제 출처를 확인해야 합니다.
/// 자세한 내용은 docs/assessment-rules.md 참고.
///
/// 표에 없어 이 코드가 정한 부분이 두 곳 있습니다. 기준이 확정되면 바꾸고
/// [version]을 올려야 합니다.
///
/// 1. **6개월 이상의 37.5~38.0℃** — 표에서 정상은 37.5까지, 주의는 38.0부터라
///    그 사이가 어느 단계에도 없습니다. 0~3개월과 3~6개월은 37.5에서 이어지므로
///    같은 방식으로 **주의**로 봅니다(정상으로 보면 미열을 놓칩니다).
/// 2. **36.5℃ 미만(저체온)** — 표는 높은 쪽만 다룹니다. 표의 정상이 범위
///    (36.5~37.5)로 정의되어 있으므로 그 아래는 정상이 아니며, **주의**로 봅니다.
///    영아 저체온도 위험 신호라 정상으로 처리하지 않았습니다.
class TemperatureRules {
  /// 임계값을 바꾸면 올려야 합니다. 과거 판정의 근거를 추적하는 데 쓰입니다.
  static const String version = 'temperature-2026-08-12';

  /// 정상 범위의 하한. 이 아래는 저체온으로 주의 처리합니다.
  static const double normalLow = 36.5;

  /// 정상 범위의 상한. 모든 연령대에서 같습니다.
  static const double normalHigh = 37.5;

  /// 연령대별 상담 권장 하한(℃).
  static double consultThreshold(int ageInMonths) {
    if (ageInMonths < 3) return 38.0;
    if (ageInMonths < 6) return 38.5;
    return 39.0;
  }

  /// 동반 증상을 판정에 함께 붙이기 시작하는 나이(개월).
  ///
  /// 출처: [26] NICE NG143. 생후 6개월을 넘은 아이는 **체온의 높이만으로**
  /// 중증 질환 여부를 판단하지 말라고 권고합니다. 그래서 이 나이부터는 판정
  /// 결과에 입력된 동반 증상을 반드시 함께 보여 줍니다.
  ///
  /// **경계가 '초과'가 아니라 '이상'인 이유**: [ageInMonthsAt]은 만 개월을
  /// 내림하므로 6개월 20일도 6입니다. `> 6`으로 두면 지침이 가리키는
  /// 6~7개월 아이가 통째로 빠집니다. 상담 권장 하한(39.0℃)이 갈리는 경계와
  /// 같은 값이라 연령 구간도 하나로 맞춰집니다.
  static const int symptomNoteFromMonths = 6;

  /// [symptomNoteFromMonths] 이상에서 판정에 함께 붙는 동반 증상 안내.
  ///
  /// 증상이 없어도 "없습니다"라고 밝힙니다. 칸을 비우면 증상을 묻지 않은
  /// 것인지 없는 것인지 알 수 없습니다.
  static String? symptomNote({
    required int ageInMonths,
    required List<Symptom> symptoms,
  }) {
    if (ageInMonths < symptomNoteFromMonths) return null;

    final listed = symptoms.isEmpty
        ? '함께 기록한 증상은 없습니다.'
        : '함께 기록한 증상: ${symptoms.map((s) => s.label).join(', ')}.';

    return '$listed 이 시기부터는 체온의 높낮이만으로 상태를 판단하지 않습니다. '
        '아이의 기운, 먹는 양, 소변량도 함께 살펴봐 주세요.';
  }

  static Assessment assess({
    required double temperatureC,
    required int ageInMonths,
    List<Symptom> symptoms = const [],
  }) {
    final consultAt = consultThreshold(ageInMonths);

    final AssessmentLevel level;
    final String guide;

    if (temperatureC >= consultAt) {
      level = AssessmentLevel.consult;
      // 생후 3개월 미만은 발열 자체가 응급 신호로 다뤄집니다.
      guide = ageInMonths < 3
          ? '${_fmt(consultAt)}℃ 이상입니다. 생후 3개월 미만은 즉시 병원 진료가 필요합니다.'
          : '${_fmt(consultAt)}℃ 이상입니다. 병원 상담을 권합니다. 수분을 충분히 주고 상태를 지켜봐 주세요.';
    } else if (temperatureC > normalHigh) {
      level = AssessmentLevel.caution;
      // "미열입니다"는 확정적 표현이라 참고적 표현으로 씁니다(안전장치 1).
      guide = '미열일 가능성이 있습니다. 2시간 간격으로 다시 재고, 옷차림과 실내 온도를 '
          '확인해 주세요. ${_fmt(consultAt)}℃ 이상이 되면 병원 상담이 필요합니다.';
    } else if (temperatureC < normalLow) {
      // 표에 없는 구간입니다(위 문서 주석 2번).
      level = AssessmentLevel.caution;
      guide = '정상 범위(${_fmt(normalLow)}~${_fmt(normalHigh)}℃)보다 낮습니다. '
          '체온계 위치를 확인해 다시 재고, 계속 낮으면 병원 상담을 권합니다.';
    } else {
      level = AssessmentLevel.normal;
      // 판정 대상이 체온이라는 것을 밝힙니다. "정상 범위입니다"만 두면
      // 아이 상태 전체가 정상이라는 말로 읽힙니다(안전장치 1).
      guide = '체온은 정상 범위입니다. 지금처럼 지켜봐 주세요.';
    }

    final note = symptomNote(ageInMonths: ageInMonths, symptoms: symptoms);

    return Assessment(
      domain: AssessmentDomain.temperature,
      level: level,
      // 증상 안내는 문단을 나눠 붙입니다. 저장되는 guide_text에 함께 들어가야
      // 나중에 판정을 다시 열어봐도 병기가 남습니다.
      guideText: note == null ? guide : '$guide\n\n$note',
      // 판정 근거를 남깁니다. 원본 기록이 지워져도 이 값은 보존됩니다.
      inputs: {
        'temperature_c': temperatureC,
        'age_in_months': ageInMonths,
        'consult_threshold_c': consultAt,
        // temperature_symptoms에 저장되는 값과 같은 표기를 씁니다.
        'symptoms': [for (final s in symptoms.toSet()) s.dbValue],
      },
      ruleVersion: version,
    );
  }

  /// 38.0 → "38.0", 39.0 → "39.0" 처럼 소수 한 자리로 맞춥니다.
  static String _fmt(double value) => value.toStringAsFixed(1);
}

/// 생년월일로부터 지난 **만 개월 수**를 셉니다.
///
/// 날짜를 30으로 나누는 근사 대신 달을 직접 셉니다. 3개월과 6개월이
/// 판정 경계라서, 하루 차이로 기준이 달라지면 안 됩니다.
/// 경계는 [0,3), [3,6), [6,∞)로 봅니다 — 3개월이 되는 날부터 3~6개월 기준입니다.
int ageInMonthsAt(DateTime birthDate, DateTime at) {
  var months = (at.year - birthDate.year) * 12 + (at.month - birthDate.month);
  // 생일이 아직 지나지 않은 달은 세지 않습니다.
  if (at.day < birthDate.day) months -= 1;
  return months < 0 ? 0 : months;
}
