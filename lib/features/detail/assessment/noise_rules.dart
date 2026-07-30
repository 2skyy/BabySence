import 'assessment.dart';

/// 수면 중 소음 판정.
///
/// 출처: [26] Berglund, B., Lindvall, T., & Schwela, D. H. (Eds.). (1999).
/// *Guidelines for community noise*. Geneva: WHO. — Table 1, "inside bedrooms"
///
/// | 건강 영향 | LAeq | 시간 기준 | LAmax fast |
/// |---|---|---|---|
/// | 수면 방해 (야간) | **30 dB** | 8시간 | **45 dB** |
/// | 음성 명료도·중등도 불쾌감 (주간·저녁) | 35 dB | 16시간 | — |
///
/// **1999년판을 쓰는 이유.** WHO 소음 지침은 이후 두 번 갱신됐지만 둘 다
/// 실외 지표입니다.
///   - 2009 *Night noise guidelines for Europe*: 40 dB L(night,outside), 잠정 55 dB
///   - 2018 *Environmental noise guidelines for the European Region*:
///     소음원별 실외 연평균 L(den)/L(night)
/// 이 앱은 스마트폰으로 침실 **실내**를 측정하므로, 침실 실내 값을 제시하는
/// 1999년판이 비교 대상으로 맞습니다.
///
/// ⚠️ **측정값 신뢰성 문제.** 위 기준은 절대 음압 수준입니다. 반면 이 앱의 dB는
/// `NoiseTracker`에서 검증되지 않은 `-15dB` 보정을 거친 값입니다. 실제 소음계와
/// 대조해 보정을 확정하기 전에는, 이 판정을 WHO 기준 충족 여부로 해석하면
/// 안 됩니다. 자세한 내용은 docs/assessment-rules.md 참고.
class NoiseRules {
  /// 임계값이나 보정이 바뀌면 올려야 합니다.
  static const String version = 'noise-who1999-2026-07-30';

  /// 침실 실내 연속 배경소음 권고 상한 (LAeq, 8시간).
  static const double sleepLAeqLimit = 30.0;

  /// 개별 소음 사건 권고 상한 (LAmax fast).
  static const double sleepLAmaxLimit = 45.0;

  /// 판정을 내기에 충분한 최소 표본 수.
  ///
  /// 30건 배치가 한 번은 쌓여야 평균이 의미를 갖습니다. 그보다 적으면
  /// 판정하지 않습니다(측정을 막 시작한 상태).
  static const int minSamples = 30;

  /// 완료된 수면 구간의 소음 통계로 판정합니다.
  ///
  /// [averageDb]는 구간 평균(LAeq에 대응), [maxDb]는 구간 최대(LAmax에 대응)입니다.
  /// 표본이 [minSamples]보다 적으면 null을 돌려줍니다 — 판정하지 않는 편이
  /// 근거 없는 안내보다 낫습니다.
  static Assessment? assess({
    required double averageDb,
    required double maxDb,
    required int sampleCount,
  }) {
    if (sampleCount < minSamples) return null;

    final overAverage = averageDb > sleepLAeqLimit;
    final overMax = maxDb > sleepLAmaxLimit;

    final AssessmentLevel level;
    final String guide;

    if (overAverage && overMax) {
      // 배경소음도 높고 놀랄 만한 순간 소음도 있었던 상태입니다.
      level = AssessmentLevel.consult;
      guide = '평균 ${_fmt(averageDb)}dB, 최대 ${_fmt(maxDb)}dB로 측정됐습니다. '
          'WHO 침실 권고(평균 ${_fmt(sleepLAeqLimit)}dB, 순간 ${_fmt(sleepLAmaxLimit)}dB)를 '
          '둘 다 넘었습니다. 소음원을 찾아 차단하고, 잠자리 위치를 바꿔보세요.';
    } else if (overMax) {
      level = AssessmentLevel.caution;
      guide = '평균은 조용했지만 최대 ${_fmt(maxDb)}dB의 순간 소음이 있었습니다. '
          'WHO는 침실에서 순간 소음이 ${_fmt(sleepLAmaxLimit)}dB를 넘지 않도록 권고합니다. '
          '갑작스러운 생활 소음에 주의해 주세요.';
    } else if (overAverage) {
      level = AssessmentLevel.caution;
      guide = '평균 ${_fmt(averageDb)}dB로 WHO 침실 권고 '
          '${_fmt(sleepLAeqLimit)}dB보다 높았습니다. 지속적인 소음원(가전·환기·바깥 소리)을 '
          '줄이거나 백색소음으로 일정하게 만들어 주세요.';
    } else {
      level = AssessmentLevel.normal;
      guide = '평균 ${_fmt(averageDb)}dB, 최대 ${_fmt(maxDb)}dB로 '
          'WHO 침실 권고 범위 안이었습니다. 현재 환경을 유지해 주세요.';
    }

    return Assessment(
      domain: AssessmentDomain.noise,
      level: level,
      guideText: guide,
      inputs: {
        'average_db': averageDb,
        'max_db': maxDb,
        'sample_count': sampleCount,
        'laeq_limit_db': sleepLAeqLimit,
        'lamax_limit_db': sleepLAmaxLimit,
        // 보정이 검증되지 않았다는 사실을 판정 근거에 함께 남깁니다.
        'mic_offset_calibrated': false,
      },
      ruleVersion: version,
    );
  }

  static String _fmt(double value) => value.toStringAsFixed(1);
}
