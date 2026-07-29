import '../../../core/services/growth_calculator.dart';

class GrowthProfile {
  final ChildSex sex;
  final DateTime birthDate;

  const GrowthProfile({required this.sex, required this.birthDate});

  Map<String, dynamic> toJson() => {
        'sex': sex.name,
        'birthDate': birthDate.toIso8601String(),
      };

  factory GrowthProfile.fromJson(Map<String, dynamic> json) => GrowthProfile(
        sex: ChildSex.values.byName(json['sex'] as String),
        birthDate: DateTime.parse(json['birthDate'] as String),
      );
}

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
      };

  factory GrowthRecord.fromJson(Map<String, dynamic> json) => GrowthRecord(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
      );
}
