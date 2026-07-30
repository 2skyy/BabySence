import '../../../core/services/baby_service.dart';
import 'growth_record.dart';
import 'growth_record_service.dart';

/// 성장 기록 화면이 필요한 데이터 접근을 한 곳에 모은 인터페이스.
///
/// [GrowthRecordPage]가 Supabase에 직접 붙지 않도록 한 단계를 둡니다.
/// 테스트에서는 이 인터페이스를 구현한 가짜 객체를 넘겨, Supabase 초기화 없이
/// 화면 동작만 검증할 수 있습니다.
abstract class GrowthRepository {
  /// 현재 로그인한 보호자의 아이. 등록된 아이가 없으면 null.
  Future<Baby?> loadBaby();

  Future<List<GrowthRecord>> loadRecords(String babyId);

  Future<void> saveRecord({
    required String babyId,
    required DateTime date,
    double? heightCm,
    double? weightKg,
  });

  Future<void> deleteRecord(String id);
}

/// 실제 구현. 기존 서비스들을 그대로 호출합니다.
class SupabaseGrowthRepository implements GrowthRepository {
  const SupabaseGrowthRepository();

  @override
  Future<Baby?> loadBaby() => BabyService.loadCurrent();

  @override
  Future<List<GrowthRecord>> loadRecords(String babyId) =>
      GrowthRecordService.loadRecords(babyId);

  @override
  Future<void> saveRecord({
    required String babyId,
    required DateTime date,
    double? heightCm,
    double? weightKg,
  }) =>
      GrowthRecordService.saveRecord(
        babyId: babyId,
        date: date,
        heightCm: heightCm,
        weightKg: weightKg,
      );

  @override
  Future<void> deleteRecord(String id) => GrowthRecordService.deleteRecord(id);
}
