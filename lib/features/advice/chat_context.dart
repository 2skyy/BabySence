import '../../core/services/baby_service.dart';
import '../../core/services/growth_calculator.dart';
import '../detail/assessment/assessment.dart';
import '../detail/assessment/temperature_rules.dart';
import '../detail/care/care_record_service.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/growth/growth_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';
import '../detail/widgets/record_history.dart';

/// 챗봇이 읽을 "이 아이에 대해 아는 것"을 모읍니다.
///
/// ## 이름을 보내지 않습니다
///
/// 개월 수·성별·기록은 답변에 필요하지만 **이름은 필요하지 않습니다.**
/// 외부 서비스로 나가는 개인정보를 필요한 만큼으로 줄입니다. 이름 없이도
/// 답변의 질은 달라지지 않습니다.
///
/// ## 영역마다 다른 기록을 붙입니다
///
/// 수면 질문에 배변 기록까지 전부 보내면 맥락이 흐려지고 요청도 커집니다.
/// 공통 정보(나이·성별·성장)에 그 영역의 최근 기록을 더합니다.
class ChatContext {
  /// 각 영역에서 가져올 최근 기록 수.
  static const int recentLimit = 5;

  /// 아이 정보와 최근 기록을 모델이 읽을 문단으로 만듭니다.
  ///
  /// 어느 한 조회가 실패해도 나머지는 보냅니다 — 맥락이 조금 빈 것이
  /// 대화가 아예 안 되는 것보다 낫습니다.
  static Future<String> build({
    required AssessmentDomain domain,
    Assessment? assessment,
  }) async {
    // 아이 조회가 실패해도 대화는 되어야 합니다. 세션이 만료됐거나 네트워크가
    // 끊기면 여기서 예외가 납니다. 감싸지 않으면 그 예외가 화면 밖으로
    // 터져 나가 대화 화면이 로딩 상태로 굳습니다.
    final Baby? baby;
    try {
      baby = await BabyService.loadCurrent();
    } catch (_) {
      return '';
    }
    if (baby == null) return '';

    final lines = <String>[];

    final months = ageInMonthsAt(baby.birthDate, DateTime.now());
    lines.add('- 생후 $months개월 (${baby.sex == ChildSex.male ? '남아' : '여아'})');

    // 판정이 있으면 먼저 놓습니다. 대화가 대개 그 판정에서 시작합니다.
    if (assessment != null) {
      lines.add(
        '- 앱 판정: ${assessment.domain.label} ${assessment.levelLabel}'
        ' (기준 ${assessment.ruleVersion})',
      );
      lines.add('- 판정 안내: ${assessment.guideText}');
    }

    final records = await _recentFor(domain, baby.id);
    if (records.isNotEmpty) {
      lines.add('- 최근 ${domain.label} 기록:');
      lines.addAll(records.map((r) => '  · $r'));
    }

    // 성장은 어느 영역에서든 배경이 됩니다. 수유·수면 질문에도 아이가
    // 또래보다 작은지 큰지가 답을 바꿉니다.
    final growth = await _latestGrowth(baby.id);
    if (growth != null) lines.add('- $growth');

    return lines.join('\n');
  }

  /// 영역에 맞는 최근 기록을 문장으로 만듭니다.
  ///
  /// 조회에 실패하면 빈 목록을 돌려줍니다. 대화는 계속되어야 합니다.
  static Future<List<String>> _recentFor(
    AssessmentDomain domain,
    String babyId,
  ) async {
    try {
      switch (domain) {
        case AssessmentDomain.temperature:
          final rows =
              await TemperatureRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows)
              '${formatRecordTime(r.measuredAt)} · ${r.summary}',
          ];

        case AssessmentDomain.feeding:
          final rows =
              await FeedingRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows) '${formatRecordTime(r.fedAt)} · ${r.summary}',
          ];

        case AssessmentDomain.diaper:
          final rows =
              await DiaperRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows)
              '${formatRecordTime(r.recordedAt)} · ${r.summary}',
          ];

        case AssessmentDomain.sleep:
        case AssessmentDomain.noise:
          final rows =
              await SleepRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows)
              '${formatRecordTime(r.startedAt)} · ${r.summary}',
          ];

        case AssessmentDomain.growth:
          // 성장은 아래에서 따로 붙입니다. 여기서 또 넣으면 두 번 나옵니다.
          return const [];

        case AssessmentDomain.skin:
        case AssessmentDomain.overall:
          // 피부는 저장되는 기록이 아직 없고, 종합은 약·병원 기록을 씁니다.
          final medications =
              await CareRecordService.loadMedications(babyId, limit: recentLimit);
          final visits =
              await CareRecordService.loadVisits(babyId, limit: recentLimit);
          return [
            for (final m in medications)
              '${formatRecordTime(m.takenAt)} · ${m.summary}',
            for (final v in visits)
              '${formatRecordTime(v.visitedAt)} · 병원 ${v.reason.label}',
          ];
      }
    } catch (_) {
      // 조회 실패는 대화를 막을 이유가 아닙니다.
      return const [];
    }
  }

  /// 가장 최근 키·몸무게 한 줄.
  static Future<String?> _latestGrowth(String babyId) async {
    try {
      // loadRecords는 측정일 오름차순이라 마지막이 가장 최근입니다.
      final rows = await GrowthRecordService.loadRecords(babyId);
      if (rows.isEmpty) return null;

      final r = rows.last;
      final parts = <String>[
        if (r.weightKg != null) '몸무게 ${r.weightKg}kg',
        if (r.heightCm != null) '키 ${r.heightCm}cm',
      ];
      if (parts.isEmpty) return null;

      return '최근 성장 기록: ${parts.join(', ')}';
    } catch (_) {
      return null;
    }
  }
}
