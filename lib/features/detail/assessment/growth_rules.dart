import '../../../core/services/growth_calculator.dart';
import 'assessment.dart';

/// 성장 판정 (체중·신장).
///
/// 출처: [6] World Health Organization. *WHO Child Growth Standards*. Geneva: WHO, 2006.
/// 국내 적용: [29] 질병관리청·대한소아과학회. 소아청소년 성장도표.
/// 성장도표는 **3세 미만(0~35개월) 구간에 WHO 기준을 그대로 적용**하므로,
/// 이 앱이 다루는 연령대에서는 두 출처의 값이 같습니다.
///
/// ## 임계값
///
/// WHO는 Z-score(표준편차)로 영양 상태를 정의합니다.
///
/// | Z-score | WHO 정의 | 이 앱의 단계 |
/// |---|---|---|
/// | −2 **미만** | 저체중(underweight) / 저신장(stunted) | 주의 |
/// | −3 **미만** | 중증 저체중 / 중증 저신장 | 상담 권장 |
///
/// 경계는 **미만**입니다. WHO가 "a Z-score less than −2"로 정의하므로
/// 정확히 −2.0은 정상입니다. 이 한 글자가 논문의 인용 정확도를 좌우합니다.
///
/// ## ⚠️ 위쪽 경계는 프로젝트 결정입니다
///
/// WHO는 **낮은 쪽만** 체중-연령·신장-연령으로 정의합니다. 과체중은
/// 체중-신장(weight-for-length) 또는 BMI로 판단하도록 되어 있고, 이 앱은
/// 그 지표를 계산하지 않습니다.
///
/// 그래서 위쪽(+2 / +3)은 **아래쪽과 대칭으로 놓은 프로젝트 결정**이며
/// 출처로 인용할 수 없습니다. 한쪽만 보면 급격한 체중 증가를 놓치므로
/// 두었습니다.
///
/// ## 백분위와의 관계
///
/// 성장 곡선 화면이 그리는 3rd/97th 백분위는 ∓1.88SD에 해당해 ∓2SD와
/// 가깝지만 같지 않습니다. **판정은 SD를 씁니다** — 논문 3-3절이
/// "연령별 표준편차 기준"이라고 밝혔기 때문입니다.
class GrowthRules {
  /// 임계값이나 계산이 바뀌면 올려야 합니다.
  static const String version = 'growth-who2006-2026-08-12';

  /// 주의 경계. 이 밖으로 나가면 주의입니다.
  static const double cautionZ = 2.0;

  /// 상담 권장 경계. 이 밖으로 나가면 상담 권장입니다.
  static const double consultZ = 3.0;

  /// WHO 성장 표준이 다루는 상한. 이 앱의 LMS 표도 0~24개월입니다.
  static const int maxAgeInMonths = 24;

  /// 체중과 신장을 함께 판정합니다.
  ///
  /// 둘 다 없거나 나이가 표 범위를 벗어나면 null입니다 — 판정하지 않는 편이
  /// 근거 없는 안내보다 낫습니다.
  ///
  /// 두 지표 중 **더 높은 단계를 그 기록의 판정**으로 삼습니다. 체중과 신장은
  /// 근거가 같은 하나의 표에서 나오므로 이 결합은 서로 다른 출처를 섞는 것이
  /// 아닙니다.
  /// [ageInMonths]는 **소수점을 살린 개월 수**여야 합니다.
  ///
  /// 만 개월(내림)을 넘기면 LMS 표 사이의 보간이 죽어 판정이 최대 한 달만큼
  /// 어린 기준으로 계산됩니다. 이 시기에는 한 달 차이가 큽니다 — 생후 89일
  /// 남아 4.6kg은 실제 z=−2.61(저체중 구간)인데, 2개월로 내리면 z=−1.52가
  /// 되어 '정상'으로 안내됐습니다. 같은 화면의 차트는 실수 개월을 써서
  /// 3백분위 아래에 점을 찍으므로 카드와 그래프가 반대말을 했습니다.
  ///
  /// 체온 규칙의 [ageInMonthsAt]은 3·6개월 경계를 넘었는지만 보므로 내림이
  /// 맞습니다. 여기와 용도가 다릅니다.
  static Assessment? assess({
    required ChildSex sex,
    required double ageInMonths,
    double? weightKg,
    double? heightCm,
  }) {
    if (ageInMonths < 0 || ageInMonths > maxAgeInMonths) return null;
    if (weightKg == null && heightCm == null) return null;

    final age = ageInMonths;

    final weightZ = weightKg == null
        ? null
        : GrowthCalculator.weightZScore(sex, age, weightKg);
    final heightZ = heightCm == null
        ? null
        : GrowthCalculator.lengthZScore(sex, age, heightCm);

    final weightLevel = weightZ == null ? null : levelForZ(weightZ);
    final heightLevel = heightZ == null ? null : levelForHeightZ(heightZ);

    final level = _higher(weightLevel, heightLevel)!;

    return Assessment(
      domain: AssessmentDomain.growth,
      level: level,
      guideText: _guide(level: level, weightZ: weightZ, heightZ: heightZ),
      // 판정 근거를 남깁니다. 원본 기록이 지워져도 이 값은 보존됩니다.
      inputs: {
        'weight_kg': ?weightKg,
        'height_cm': ?heightCm,
        if (weightZ != null) 'weight_z': _round(weightZ),
        if (heightZ != null) 'height_z': _round(heightZ),
        'age_in_months': _round(ageInMonths),
        'sex': sex.name,
        'caution_z': cautionZ,
        'consult_z': consultZ,
        // 위쪽 경계가 출처 없는 값이라는 사실을 근거에 함께 남깁니다.
        'upper_bound_is_project_decision': true,
      },
      ruleVersion: version,
    );
  }

  /// Z-score 하나를 단계로 바꿉니다. 위아래 대칭입니다.
  ///
  /// 경계는 **초과**입니다 — WHO의 "less than −2"를 그대로 옮긴 것이라
  /// 정확히 ±2.0은 정상입니다.
  static AssessmentLevel levelForZ(double z) {
    final distance = z.abs();
    if (distance > consultZ) return AssessmentLevel.consult;
    if (distance > cautionZ) return AssessmentLevel.caution;
    return AssessmentLevel.normal;
  }

  /// 키의 Z-score를 단계로 바꿉니다. **아래쪽만** 봅니다.
  ///
  /// WHO는 신장-연령에 저신장(stunting, "less than −2")만 정의하고
  /// **위쪽 경계를 두지 않습니다.** 체중의 위쪽 경계는 급격한 증가를
  /// 놓치지 않으려는 프로젝트 결정이지만(위 [levelForZ] 주석), 그 이유는
  /// 키에 해당하지 않습니다. 같은 대칭 규칙을 키에 그대로 쓰면 **잘 크는
  /// 아이의 보호자에게 소아과 상담을 권하게 됩니다.**
  static AssessmentLevel levelForHeightZ(double z) =>
      z > 0 ? AssessmentLevel.normal : levelForZ(z);

  /// 둘 중 더 높은 단계. 한쪽이 null이면 나머지를 씁니다.
  static AssessmentLevel? _higher(AssessmentLevel? a, AssessmentLevel? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.index >= b.index ? a : b;
  }

  static String _guide({
    required AssessmentLevel level,
    required double? weightZ,
    required double? heightZ,
  }) {
    final parts = <String>[];
    if (weightZ != null) parts.add('체중 ${_describe(weightZ)}');
    if (heightZ != null) parts.add('키 ${_describe(heightZ)}');
    final measured = parts.join(', ');

    switch (level) {
      case AssessmentLevel.normal:
        // **'또래 범위 안'이라고 덧붙이지 않습니다.** 키는 위쪽을 정상으로
        // 보므로(levelForHeightZ), 잘 크는 아이에서 "키 또래보다 많이 큼로
        // 또래 범위 안입니다"처럼 한 문장이 스스로를 부정했습니다. 단계는
        // levelLabel이 따로 말하니 여기서는 잰 것만 옮깁니다. 아래 두 갈래와
        // 문장 모양도 같아집니다.
        return '$measured입니다. '
            '성장은 한 번의 측정보다 추세가 중요하니 기록을 이어가 주세요.';
      case AssessmentLevel.caution:
        return '$measured입니다. 또래 대비 차이가 있어 지켜볼 구간입니다. '
            '수유량과 식사량을 함께 살피고, 다음 측정에서도 같은 방향이면 '
            '소아과에서 상담해 보세요.';
      case AssessmentLevel.consult:
        return '$measured로 또래와 차이가 큽니다. 소아과 상담을 권합니다. '
            '측정 방법(옷·기저귀 무게, 눕힌 자세)도 함께 확인해 주세요.';
    }
  }

  /// Z-score를 보호자가 읽을 수 있는 말로 바꿉니다.
  ///
  /// 백분위로 바꿔 말하면 "3백분위"가 등수처럼 읽혀 오해를 삽니다.
  /// 경계 부호는 [levelForZ]와 같아야 합니다. 다르면 정확히 ±2.0에서
  /// 단계는 '정상'인데 말은 '또래보다 작음'이 되어 서로 어긋납니다.
  static String _describe(double z) {
    if (z < -consultZ) return '또래보다 많이 작음';
    if (z < -cautionZ) return '또래보다 작음';
    if (z > consultZ) return '또래보다 많이 큼';
    if (z > cautionZ) return '또래보다 큼';
    return '또래 범위';
  }

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}
