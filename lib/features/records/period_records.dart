import '../../core/services/baby_service.dart';
import '../detail/care/care_record_service.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/growth/growth_record.dart';
import '../detail/growth/growth_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';
import 'record_period.dart';

/// 한 기간에서 읽어 온 **날것의** 기록들.
///
/// 합치고·거르고·원으로 만드는 일은 여기서 하지 않습니다. 그것들은 화면이
/// 하고, 화면을 띄우는 테스트가 그 계산까지 함께 지나가야 하기 때문입니다.
/// 여기가 하는 일은 조회 하나뿐입니다.
class PeriodRecords {
  /// 아이가 아직 없으면 기록 자체가 불가능합니다. 조회 실패와는 다릅니다 —
  /// 실패는 예외로 알리고, 이건 성공한 조회의 결과입니다.
  final bool hasBaby;

  final List<FeedingRecord> feedings;
  final List<DiaperRecord> diapers;
  final List<SleepRecord> sleeps;
  final List<TemperatureRecord> temperatures;
  final List<GrowthRecord> growths;
  final List<MedicationRecord> medications;
  final List<HospitalVisit> visits;

  /// 조회가 한도에 걸려 기간의 일부만 읽었는지.
  ///
  /// 서비스들은 limit까지만 돌려주고 잘렸다는 말을 하지 않습니다. 그대로 두면
  /// "8월에 수유 900회"라고 적어 놓고 실제로는 900건만 센 화면이 됩니다.
  final bool truncated;

  const PeriodRecords({
    this.hasBaby = true,
    this.feedings = const [],
    this.diapers = const [],
    this.sleeps = const [],
    this.temperatures = const [],
    this.growths = const [],
    this.medications = const [],
    this.visits = const [],
    this.truncated = false,
  });

  static const noBaby = PeriodRecords(hasBaby: false);
}

/// 한 기간을 읽는 일.
///
/// 화면이 이것만 통해 읽으므로, 테스트는 Supabase 없이도 화면을 띄워
/// 눈금 전환·기간 이동·날짜 선택을 실제로 돌려 볼 수 있습니다.
typedef PeriodRecordsLoad = Future<PeriodRecords> Function(RecordPeriod period);

/// 기간이 길수록 한도를 늘립니다.
///
/// 고정값에 기대면 "2026년 8월"이라 적어 놓고 실제로는 최신 몇 건만 그리게
/// 됩니다. 신생아기에는 수유만 하루 열 번이 넘어 달의 앞쪽이 통째로 빠집니다.
int windowFor(RecordPeriod period) => period.days.length * 30 + 60;

/// 진짜 조회. Supabase를 부릅니다.
Future<PeriodRecords> loadPeriodRecords(RecordPeriod period) async {
  final baby = await BabyService.loadCurrent();
  if (baby == null) return PeriodRecords.noBaby;

  // 기간 시작 **하루 전**부터 읽습니다. 전날 밤에 재워 첫날 새벽에 깬
  // 잠은 시작 시각이 기간 밖에 있지만, 첫날 원의 0~6시로 그려져야 합니다.
  final since = DateTime(
    period.start.year,
    period.start.month,
    period.start.day - 1,
  );

  // 상한도 함께 줍니다. 서비스는 최신순으로 정렬해 한도만큼 자르므로,
  // 상한이 없으면 한도가 **오늘 쪽부터** 채워집니다. 하루 열 번 기록하는
  // 시기에 지난달을 펴면 한도가 최근 며칠로 다 차 버려, 보고 있는 기간의
  // 기록이 한 건도 오지 않고 화면은 그것을 '기록 없음'으로 말합니다.
  final until = period.end;

  final window = windowFor(period);

  // 동시에 부릅니다. 하나씩 기다리면 종류 수만큼 느려집니다.
  final results = await Future.wait([
    FeedingRecordService.loadRecent(baby.id,
        limit: window, since: since, until: until),
    DiaperRecordService.loadRecent(baby.id,
        limit: window, since: since, until: until),
    SleepRecordService.loadRecent(baby.id,
        limit: window, since: since, until: until),
    TemperatureRecordService.loadRecent(baby.id,
        limit: window, since: since, until: until),
    GrowthRecordService.loadRecords(baby.id),
    CareRecordService.loadMedications(baby.id,
        limit: window, since: since, until: until),
    CareRecordService.loadVisits(baby.id,
        limit: window, since: since, until: until),
  ]);

  return PeriodRecords(
    feedings: results[0] as List<FeedingRecord>,
    diapers: results[1] as List<DiaperRecord>,
    sleeps: results[2] as List<SleepRecord>,
    temperatures: results[3] as List<TemperatureRecord>,
    growths: results[4] as List<GrowthRecord>,
    medications: results[5] as List<MedicationRecord>,
    visits: results[6] as List<HospitalVisit>,
    // 한도만큼 꽉 차서 온 종류가 있으면 더 있을 수 있습니다. 성장은 한도
    // 없이 전부 읽으므로 여기서 빠집니다.
    truncated: results
        .take(4)
        .followedBy(results.skip(5))
        .any((r) => (r as List).length >= window),
  );
}
