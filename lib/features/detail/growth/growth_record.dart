/// growth_records 테이블의 한 행.
class GrowthRecord {
  final String id;
  final DateTime date;
  final double? heightCm;
  final double? weightKg;

  const GrowthRecord({
    required this.id,
    required this.date,
    this.heightCm,
    this.weightKg,
  });

  factory GrowthRecord.fromMap(Map<String, dynamic> map) => GrowthRecord(
        id: map['id'] as String,
        date: DateTime.parse(map['recorded_on'] as String),
        heightCm: (map['height_cm'] as num?)?.toDouble(),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
      );
}
