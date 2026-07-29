import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project/core/services/growth_calculator.dart';

void main() {
  group('GrowthCalculator', () {
    test('median (P50) weight-for-age matches WHO reference values', () {
      expect(GrowthCalculator.weightAtZ(ChildSex.male, 0, GrowthPercentiles.p50), closeTo(3.3464, 0.001));
      expect(GrowthCalculator.weightAtZ(ChildSex.male, 12, GrowthPercentiles.p50), closeTo(9.646, 0.001));
      expect(GrowthCalculator.weightAtZ(ChildSex.female, 24, GrowthPercentiles.p50), closeTo(11.4741, 0.001));
    });

    test('median (P50) length-for-age matches WHO reference values', () {
      expect(GrowthCalculator.lengthAtZ(ChildSex.male, 0, GrowthPercentiles.p50), closeTo(49.8842, 0.001));
      expect(GrowthCalculator.lengthAtZ(ChildSex.female, 12, GrowthPercentiles.p50), closeTo(74.0049, 0.001));
    });

    test('weightZScore and weightAtZ are inverses of each other', () {
      final value = GrowthCalculator.weightAtZ(ChildSex.male, 6, 1.5);
      final z = GrowthCalculator.weightZScore(ChildSex.male, 6, value);
      expect(z, closeTo(1.5, 1e-6));
    });

    test('lengthZScore and lengthAtZ are inverses of each other', () {
      final value = GrowthCalculator.lengthAtZ(ChildSex.female, 18, -1.0);
      final z = GrowthCalculator.lengthZScore(ChildSex.female, 18, value);
      expect(z, closeTo(-1.0, 1e-6));
    });

    test('interpolates between monthly checkpoints', () {
      final at6 = GrowthCalculator.weightAtZ(ChildSex.male, 6, 0);
      final at7 = GrowthCalculator.weightAtZ(ChildSex.male, 7, 0);
      final atHalf = GrowthCalculator.weightAtZ(ChildSex.male, 6.5, 0);
      expect(atHalf, greaterThan(at6));
      expect(atHalf, lessThan(at7));
    });
  });
}
