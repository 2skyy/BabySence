import 'assessment.dart';

/// 수면 환경 소음 판정.
///
/// ## 임계값
///
/// | 측정 소음도 (dB(A)) | 단계 | 근거 |
/// |---|---|---|
/// | 30 미만 | 정상 | [28] WHO 침실 권고 상한 |
/// | 30 ~ 50 | 주의 | 수면 방해가 시작되는 구간 |
/// | 50 초과 | 개선 권장 | [24] 신생아실 권장 소음 상한 |
///
/// 출처
/// - [28] Berglund, B., Lindvall, T., & Schwela, D. H. (Eds.). (1999).
///   *Guidelines for community noise*. Geneva: WHO. — Table 1, "inside bedrooms":
///   수면을 위한 침실 내 정상 상태 소음 **30 dB LAeq**.
/// - [24] Hugh, S. C., et al. (2014). Infant sleep machines and hazardous sound
///   pressure levels. *Pediatrics*, 133(4), 677-681. — 신생아실 권장 소음 상한
///   **50 dB(A)**.
///
/// ## 왜 WHO의 45dB이 경계가 아닌가
///
/// WHO는 침실의 **순간 소음 사건**을 45 dB LAmax로 권고합니다. 이 앱은 그
/// 값을 경계로 쓰지 않고 **신생아실 상한 50dB**을 씁니다. 대상이 영유아이고,
/// 50dB이 영유아가 자는 공간을 직접 겨냥해 제시된 값이기 때문입니다.
/// 순간 최대값은 판정 근거(`inputs`)와 안내 문구에 함께 남깁니다.
///
/// **[maxDb]는 평활을 거치지 않은 값입니다.** 2026-08-13 이전에는 이동평균을
/// 거친 값에서 세어, 배경 40dB에 90dB가 한 번 들어와도 45.25dB로 기록됐습니다.
/// 단계는 평균으로 정하므로 그때도 판정 등급은 옳았지만, "가장 컸던 소리"라는
/// 문구와 LAmax 대응 주장은 사실이 아니었습니다. 그래서 규칙 버전을
/// 올렸습니다 — 같은 `max_db` 키가 날짜에 따라 다른 것을 가리킵니다.
///
/// ## ⚠️ 측정값 신뢰성 문제
///
/// 위 기준은 절대 음압 수준입니다. 반면 이 앱의 dB는 `NoiseTracker`에서
/// **검증되지 않은 `-15dB` 보정**을 거친 값입니다. 실제 소음계와 대조해
/// 보정을 확정하기 전에는, 이 판정을 절대 기준 충족 여부로 해석하면 안 됩니다.
/// 자세한 내용은 docs/assessment-rules.md 참고.
class NoiseRules {
  /// 임계값이나 보정이 바뀌면 올려야 합니다.
  static const String version = 'noise-2026-08-13';

  /// 이 값 미만이면 정상. WHO 침실 권고 상한입니다.
  static const double normalLimit = 30.0;

  /// 이 값을 넘으면 개선 권장. 신생아실 권장 소음 상한입니다.
  static const double improveLimit = 50.0;

  /// 판정을 내기에 충분한 최소 표본 수.
  ///
  /// 30건 배치가 한 번은 쌓여야 평균이 의미를 갖습니다. 그보다 적으면
  /// 판정하지 않습니다(측정을 막 시작한 상태).
  static const int minSamples = 30;

  /// 완료된 수면 구간의 소음 통계로 판정합니다.
  ///
  /// 단계는 **평균([averageDb])**으로 정합니다. 30dB과 50dB 모두 지속되는
  /// 배경 소음 수준을 가리키는 값이기 때문입니다. [maxDb]는 경계로 쓰지
  /// 않고 안내와 근거에만 남깁니다 — 그래서 [maxDb]의 뜻이 바뀌어도 과거
  /// 판정의 **등급**은 그대로입니다.
  ///
  /// 표본이 [minSamples]보다 적으면 null을 돌려줍니다 — 판정하지 않는 편이
  /// 근거 없는 안내보다 낫습니다.
  static Assessment? assess({
    required double averageDb,
    required double maxDb,
    required int sampleCount,
  }) {
    if (sampleCount < minSamples) return null;

    final AssessmentLevel level;
    final String guide;

    if (averageDb > improveLimit) {
      level = AssessmentLevel.consult;
      guide = '평균 ${_fmt(averageDb)}dB로 측정됐습니다. '
          '영유아가 자는 공간의 권장 상한(${_fmt(improveLimit)}dB)을 넘었습니다. '
          '소음원을 찾아 차단하고, 백색소음을 쓰고 있다면 음량을 낮추거나 '
          '기기를 아기에게서 멀리 두세요.';
    } else if (averageDb >= normalLimit) {
      level = AssessmentLevel.caution;
      guide = '평균 ${_fmt(averageDb)}dB로 수면 방해가 시작되는 구간입니다. '
          'WHO는 침실 소음을 ${_fmt(normalLimit)}dB 이하로 권고합니다. '
          '지속적인 소음원(가전·환기·바깥 소리)을 줄여 보세요.';
    } else {
      level = AssessmentLevel.normal;
      guide = '평균 ${_fmt(averageDb)}dB로 조용한 편입니다. '
          '현재 환경을 유지해 주세요.';
    }

    return Assessment(
      domain: AssessmentDomain.noise,
      level: level,
      guideText: '$guide 측정 중 가장 컸던 소리는 ${_fmt(maxDb)}dB였습니다.',
      inputs: {
        'average_db': averageDb,
        'max_db': maxDb,
        'sample_count': sampleCount,
        'normal_limit_db': normalLimit,
        'improve_limit_db': improveLimit,
        // 보정이 검증되지 않았다는 사실을 판정 근거에 함께 남깁니다.
        'mic_offset_calibrated': false,
      },
      ruleVersion: version,
    );
  }

  static String _fmt(double value) => value.toStringAsFixed(1);
}
