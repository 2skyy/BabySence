/// WHO Child Growth Standards (2006), LMS parameters at monthly checkpoints
/// (0-24 months), sourced from the official WHO reference tables published at
/// https://github.com/WorldHealthOrganization/anthro
/// (data-raw/growthstandards/weianthro.txt, lenanthro.txt).
class GrowthLms {
  final int month;
  final double l;
  final double m;
  final double s;

  const GrowthLms({required this.month, required this.l, required this.m, required this.s});
}

class WhoGrowthStandards {
  static const List<GrowthLms> weightForAgeBoys = [
    GrowthLms(month: 0, l: 0.3487, m: 3.3464, s: 0.14602),
    GrowthLms(month: 1, l: 0.2303, m: 4.4525, s: 0.13413),
    GrowthLms(month: 2, l: 0.1969, m: 5.5714, s: 0.12382),
    GrowthLms(month: 3, l: 0.174, m: 6.369, s: 0.11732),
    GrowthLms(month: 4, l: 0.1551, m: 7.0069, s: 0.11313),
    GrowthLms(month: 5, l: 0.1396, m: 7.5077, s: 0.11081),
    GrowthLms(month: 6, l: 0.1256, m: 7.9389, s: 0.10957),
    GrowthLms(month: 7, l: 0.1134, m: 8.2963, s: 0.10902),
    GrowthLms(month: 8, l: 0.1019, m: 8.62, s: 0.10882),
    GrowthLms(month: 9, l: 0.0917, m: 8.9019, s: 0.10881),
    GrowthLms(month: 10, l: 0.0821, m: 9.1618, s: 0.1089),
    GrowthLms(month: 11, l: 0.0729, m: 9.4136, s: 0.10906),
    GrowthLms(month: 12, l: 0.0645, m: 9.646, s: 0.10925),
    GrowthLms(month: 13, l: 0.0563, m: 9.8772, s: 0.10949),
    GrowthLms(month: 14, l: 0.0487, m: 10.0944, s: 0.10976),
    GrowthLms(month: 15, l: 0.0412, m: 10.3139, s: 0.11008),
    GrowthLms(month: 16, l: 0.0343, m: 10.5228, s: 0.11041),
    GrowthLms(month: 17, l: 0.0276, m: 10.7289, s: 0.11078),
    GrowthLms(month: 18, l: 0.021, m: 10.9393, s: 0.1112),
    GrowthLms(month: 19, l: 0.0149, m: 11.1409, s: 0.11163),
    GrowthLms(month: 20, l: 0.0087, m: 11.3478, s: 0.11212),
    GrowthLms(month: 21, l: 0.0029, m: 11.5474, s: 0.11261),
    GrowthLms(month: 22, l: -0.0029, m: 11.7528, s: 0.11315),
    GrowthLms(month: 23, l: -0.0083, m: 11.951, s: 0.11369),
    GrowthLms(month: 24, l: -0.0136, m: 12.1482, s: 0.11425),
  ];

  static const List<GrowthLms> weightForAgeGirls = [
    GrowthLms(month: 0, l: 0.3809, m: 3.2322, s: 0.14171),
    GrowthLms(month: 1, l: 0.1727, m: 4.1716, s: 0.13738),
    GrowthLms(month: 2, l: 0.0959, m: 5.1315, s: 0.12998),
    GrowthLms(month: 3, l: 0.0407, m: 5.8393, s: 0.12622),
    GrowthLms(month: 4, l: -0.0053, m: 6.428, s: 0.12401),
    GrowthLms(month: 5, l: -0.0428, m: 6.8959, s: 0.12274),
    GrowthLms(month: 6, l: -0.0759, m: 7.3016, s: 0.12204),
    GrowthLms(month: 7, l: -0.1039, m: 7.6416, s: 0.12178),
    GrowthLms(month: 8, l: -0.1292, m: 7.9534, s: 0.12181),
    GrowthLms(month: 9, l: -0.1507, m: 8.2259, s: 0.12199),
    GrowthLms(month: 10, l: -0.1698, m: 8.4769, s: 0.12222),
    GrowthLms(month: 11, l: -0.1873, m: 8.7207, s: 0.12247),
    GrowthLms(month: 12, l: -0.2022, m: 8.9462, s: 0.12267),
    GrowthLms(month: 13, l: -0.216, m: 9.1722, s: 0.12283),
    GrowthLms(month: 14, l: -0.2277, m: 9.3861, s: 0.12294),
    GrowthLms(month: 15, l: -0.2385, m: 9.6038, s: 0.12299),
    GrowthLms(month: 16, l: -0.2478, m: 9.8124, s: 0.12303),
    GrowthLms(month: 17, l: -0.2561, m: 10.0196, s: 0.12305),
    GrowthLms(month: 18, l: -0.2637, m: 10.2324, s: 0.12309),
    GrowthLms(month: 19, l: -0.2702, m: 10.4372, s: 0.12315),
    GrowthLms(month: 20, l: -0.2763, m: 10.6481, s: 0.12324),
    GrowthLms(month: 21, l: -0.2814, m: 10.8521, s: 0.12335),
    GrowthLms(month: 22, l: -0.2862, m: 11.0633, s: 0.12351),
    GrowthLms(month: 23, l: -0.2903, m: 11.2684, s: 0.12369),
    GrowthLms(month: 24, l: -0.294, m: 11.4741, s: 0.12389),
  ];

  static const List<GrowthLms> lengthForAgeBoys = [
    GrowthLms(month: 0, l: 1.0, m: 49.8842, s: 0.03795),
    GrowthLms(month: 1, l: 1.0, m: 54.6645, s: 0.03559),
    GrowthLms(month: 2, l: 1.0, m: 58.4384, s: 0.03423),
    GrowthLms(month: 3, l: 1.0, m: 61.4013, s: 0.03329),
    GrowthLms(month: 4, l: 1.0, m: 63.9041, s: 0.03257),
    GrowthLms(month: 5, l: 1.0, m: 65.8912, s: 0.03204),
    GrowthLms(month: 6, l: 1.0, m: 67.6435, s: 0.03165),
    GrowthLms(month: 7, l: 1.0, m: 69.1615, s: 0.03139),
    GrowthLms(month: 8, l: 1.0, m: 70.6224, s: 0.03124),
    GrowthLms(month: 9, l: 1.0, m: 71.9714, s: 0.03117),
    GrowthLms(month: 10, l: 1.0, m: 73.2653, s: 0.03118),
    GrowthLms(month: 11, l: 1.0, m: 74.5464, s: 0.03125),
    GrowthLms(month: 12, l: 1.0, m: 75.7391, s: 0.03137),
    GrowthLms(month: 13, l: 1.0, m: 76.9304, s: 0.03154),
    GrowthLms(month: 14, l: 1.0, m: 78.0451, s: 0.03174),
    GrowthLms(month: 15, l: 1.0, m: 79.1613, s: 0.03197),
    GrowthLms(month: 16, l: 1.0, m: 80.2113, s: 0.03222),
    GrowthLms(month: 17, l: 1.0, m: 81.234, s: 0.03249),
    GrowthLms(month: 18, l: 1.0, m: 82.2628, s: 0.03279),
    GrowthLms(month: 19, l: 1.0, m: 83.2318, s: 0.0331),
    GrowthLms(month: 20, l: 1.0, m: 84.2074, s: 0.03342),
    GrowthLms(month: 21, l: 1.0, m: 85.1291, s: 0.03375),
    GrowthLms(month: 22, l: 1.0, m: 86.0589, s: 0.0341),
    GrowthLms(month: 23, l: 1.0, m: 86.9392, s: 0.03445),
    GrowthLms(month: 24, l: 1.0, m: 87.8018, s: 0.03479),
  ];

  static const List<GrowthLms> lengthForAgeGirls = [
    GrowthLms(month: 0, l: 1.0, m: 49.1477, s: 0.0379),
    GrowthLms(month: 1, l: 1.0, m: 53.6326, s: 0.03641),
    GrowthLms(month: 2, l: 1.0, m: 57.0796, s: 0.03568),
    GrowthLms(month: 3, l: 1.0, m: 59.7773, s: 0.0352),
    GrowthLms(month: 4, l: 1.0, m: 62.1071, s: 0.03486),
    GrowthLms(month: 5, l: 1.0, m: 64.019, s: 0.03463),
    GrowthLms(month: 6, l: 1.0, m: 65.751, s: 0.03448),
    GrowthLms(month: 7, l: 1.0, m: 67.2842, s: 0.03441),
    GrowthLms(month: 8, l: 1.0, m: 68.7732, s: 0.0344),
    GrowthLms(month: 9, l: 1.0, m: 70.1463, s: 0.03444),
    GrowthLms(month: 10, l: 1.0, m: 71.4656, s: 0.03452),
    GrowthLms(month: 11, l: 1.0, m: 72.7788, s: 0.03464),
    GrowthLms(month: 12, l: 1.0, m: 74.0049, s: 0.03479),
    GrowthLms(month: 13, l: 1.0, m: 75.2297, s: 0.03496),
    GrowthLms(month: 14, l: 1.0, m: 76.377, s: 0.03514),
    GrowthLms(month: 15, l: 1.0, m: 77.5258, s: 0.03534),
    GrowthLms(month: 16, l: 1.0, m: 78.6055, s: 0.03555),
    GrowthLms(month: 17, l: 1.0, m: 79.6559, s: 0.03576),
    GrowthLms(month: 18, l: 1.0, m: 80.7121, s: 0.03598),
    GrowthLms(month: 19, l: 1.0, m: 81.708, s: 0.0362),
    GrowthLms(month: 20, l: 1.0, m: 82.7116, s: 0.03643),
    GrowthLms(month: 21, l: 1.0, m: 83.6595, s: 0.03665),
    GrowthLms(month: 22, l: 1.0, m: 84.6154, s: 0.03689),
    GrowthLms(month: 23, l: 1.0, m: 85.5184, s: 0.03711),
    GrowthLms(month: 24, l: 1.0, m: 86.4008, s: 0.03733),
  ];
}
