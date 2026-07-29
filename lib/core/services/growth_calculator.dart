import 'dart:math';

import '../constants/who_growth_standards.dart';

enum ChildSex { male, female }

/// Standard normal Z-values for the percentiles WHO growth charts conventionally show.
class GrowthPercentiles {
  static const double p3 = -1.8808;
  static const double p15 = -1.0364;
  static const double p50 = 0;
  static const double p85 = 1.0364;
  static const double p97 = 1.8808;

  static const List<double> standard = [p3, p15, p50, p85, p97];
}

/// Converts between raw measurements and WHO growth-standard Z-scores using
/// the LMS (Box-Cox) method: https://www.who.int/tools/child-growth-standards
class GrowthCalculator {
  static List<GrowthLms> _weightTable(ChildSex sex) =>
      sex == ChildSex.male ? WhoGrowthStandards.weightForAgeBoys : WhoGrowthStandards.weightForAgeGirls;

  static List<GrowthLms> _lengthTable(ChildSex sex) =>
      sex == ChildSex.male ? WhoGrowthStandards.lengthForAgeBoys : WhoGrowthStandards.lengthForAgeGirls;

  /// Linearly interpolates the LMS triplet for a given age in months (0-24).
  static GrowthLms _lmsAt(List<GrowthLms> table, double ageInMonths) {
    final clamped = ageInMonths.clamp(0, table.last.month.toDouble());
    final lower = table.lastWhere((e) => e.month <= clamped, orElse: () => table.first);
    final upper = table.firstWhere((e) => e.month >= clamped, orElse: () => table.last);
    if (lower.month == upper.month) return lower;

    final t = (clamped - lower.month) / (upper.month - lower.month);
    return GrowthLms(
      month: clamped.round(),
      l: lower.l + (upper.l - lower.l) * t,
      m: lower.m + (upper.m - lower.m) * t,
      s: lower.s + (upper.s - lower.s) * t,
    );
  }

  static double _valueForZ(GrowthLms lms, double z) {
    if (lms.l == 0) return lms.m * exp(lms.s * z);
    return lms.m * pow(1 + lms.l * lms.s * z, 1 / lms.l);
  }

  static double _zForValue(GrowthLms lms, double value) {
    if (lms.l == 0) return log(value / lms.m) / lms.s;
    return (pow(value / lms.m, lms.l) - 1) / (lms.l * lms.s);
  }

  /// Weight (kg) at the given percentile Z-score, for the given age in months.
  static double weightAtZ(ChildSex sex, double ageInMonths, double z) {
    return _valueForZ(_lmsAt(_weightTable(sex), ageInMonths), z);
  }

  /// Length/height (cm) at the given percentile Z-score, for the given age in months.
  static double lengthAtZ(ChildSex sex, double ageInMonths, double z) {
    return _valueForZ(_lmsAt(_lengthTable(sex), ageInMonths), z);
  }

  /// Z-score of a measured weight (kg) at the given age in months.
  static double weightZScore(ChildSex sex, double ageInMonths, double weightKg) {
    return _zForValue(_lmsAt(_weightTable(sex), ageInMonths), weightKg);
  }

  /// Z-score of a measured length/height (cm) at the given age in months.
  static double lengthZScore(ChildSex sex, double ageInMonths, double heightCm) {
    return _zForValue(_lmsAt(_lengthTable(sex), ageInMonths), heightCm);
  }
}
