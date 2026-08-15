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
/// [ChatContext.build]가 돌려주는 것.
///
/// 글만 돌려주면 **"기록이 없다"와 "못 읽었다"를 구별할 수 없습니다.**
/// 화면은 빈 맥락을 보고 "아이 정보를 등록하면 기록을 함께 보고 답해
/// 드려요"라고 말했습니다 — 아이는 등록돼 있고 조회가 실패한 것뿐인데요.
/// 이 프로젝트가 지키기로 한 첫 번째 원칙을 상담 화면만 어기고 있었습니다.
class ChatContextResult {
  /// 모델이 읽을 문단. 담을 것이 없으면 빈 문자열입니다.
  final String text;

  /// 아이 정보나 기록 중 **하나라도 못 읽었는지.**
  ///
  /// 입구가 홈 단추 하나가 되면서 더 중요해졌습니다. 그 대화는 "전부 알고
  /// 있다"는 전제로 열리는데, 한 영역이 조용히 빠지면 모델은 그냥 "기록이
  /// 없다"고 답합니다.
  final bool failed;

  const ChatContextResult({required this.text, required this.failed});
}

class ChatContext {
  /// 각 영역에서 가져올 최근 기록 수.
  static const int recentLimit = 5;

  /// 종합 상담에서 **영역마다** 담는 건수.
  ///
  /// 영역이 다섯이라 5건씩 담으면 25줄이 되고, 서버의 맥락 길이 상한
  /// (MAX_CONTEXT_CHARS, 기본 2000자)에 걸려 뒤쪽 영역이 통째로 잘립니다.
  /// 잘리면 어느 영역이 빠졌는지 아무도 모릅니다.
  static const int overallLimit = 3;

  /// 아이 정보와 최근 기록을 모델이 읽을 문단으로 만듭니다.
  ///
  /// 어느 한 조회가 실패해도 나머지는 보냅니다 — 맥락이 조금 빈 것이
  /// 대화가 아예 안 되는 것보다 낫습니다. 다만 **실패했다는 사실은
  /// 돌려줍니다**([ChatContextResult.failed]). 감추면 화면이 "기록이 없다"고
  /// 말하게 됩니다.
  static Future<ChatContextResult> build({
    required AssessmentDomain domain,
    Assessment? assessment,
  }) async {
    // 판정은 **화면이 이미 들고 있는 값**이라 조회와 무관합니다. 먼저 담아
    // 두면, 아이 조회가 실패해도 이것만은 살아남습니다. 예전에는 실패 시
    // 곧바로 빈 문자열을 돌려주어 판정까지 함께 버렸습니다 — 판정에서
    // 넘어온 대화인데 그 판정을 모른 채 답하게 됐습니다.
    final lines = <String>[];
    void addAssessment() {
      if (assessment == null) return;
      lines.add(
        '- 앱 판정: ${assessment.domain.label} ${assessment.levelLabel}'
        ' (기준 ${assessment.ruleVersion})',
      );
      lines.add('- 판정 안내: ${assessment.guideText}');
    }

    // 아이 조회가 실패해도 대화는 되어야 합니다. 세션이 만료됐거나 네트워크가
    // 끊기면 여기서 예외가 납니다. 감싸지 않으면 그 예외가 화면 밖으로
    // 터져 나가 대화 화면이 로딩 상태로 굳습니다.
    final Baby? baby;
    try {
      baby = await BabyService.loadCurrent();
    } catch (_) {
      addAssessment();
      return ChatContextResult(text: lines.join('\n'), failed: true);
    }
    if (baby == null) {
      // 아이가 **없는** 것은 실패가 아닙니다. 등록하라고 안내하면 됩니다.
      addAssessment();
      return ChatContextResult(text: lines.join('\n'), failed: false);
    }

    final now = DateTime.now();
    // **지금이 언제인지 먼저 밝힙니다.** 없으면 아래 기록의 날짜가 얼마나
    // 지난 것인지 모델이 알 수 없습니다.
    lines.add('- 지금: ${_contextTime(now)}');

    final months = ageInMonthsAt(baby.birthDate, now);
    lines.add('- 생후 $months개월 (${baby.sex == ChildSex.male ? '남아' : '여아'})');

    // 판정이 있으면 개월 수 바로 뒤에 놓습니다. 대화가 대개 거기서 시작합니다.
    addAssessment();

    var failed = false;

    if (domain == AssessmentDomain.overall) {
      // **종합은 전부 담습니다.** 홈의 상담 단추가 여기로 옵니다.
      //
      // 각 기록 화면에 있던 상담 아이콘을 없애면서, 이 대화 하나가 모든
      // 질문을 받게 됐습니다. 예전처럼 약·병원만 담으면 "어젯밤 잘 잤나요"
      // 같은 질문에 아무 근거 없이 답하게 됩니다.
      final everything = await _everything(baby.id);
      failed = everything.failed;
      for (final entry in everything.byLabel) {
        lines.add('- 최근 ${entry.key} 기록:');
        lines.addAll(entry.value.map((r) => '  · $r'));
      }
    } else {
      final records = await _recentFor(domain, baby.id);
      if (records == null) {
        failed = true;
      } else if (records.isNotEmpty) {
        lines.add('- 최근 ${domain.label} 기록:');
        lines.addAll(records.map((r) => '  · $r'));
      }
    }

    // 성장은 어느 영역에서든 배경이 됩니다. 수유·수면 질문에도 아이가
    // 또래보다 작은지 큰지가 답을 바꿉니다.
    try {
      final growth = await _latestGrowth(baby.id);
      if (growth != null) lines.add('- $growth');
    } catch (_) {
      failed = true;
    }

    return ChatContextResult(text: lines.join('\n'), failed: failed);
  }

  /// 맥락에 적을 시각.
  ///
  /// 화면용 [formatRecordTime]을 쓰면 안 됩니다. 그쪽은 "오늘 오후 3:20",
  /// "2/14 오후 3:20"처럼 **연도가 없습니다** — 사람이 최근 기록을 훑을
  /// 때는 충분하지만, 모델에게는 반년 전 고열이 '최근 체온 기록'으로
  /// 읽힙니다. 게다가 대화 어디에도 "지금이 언제인지"가 없습니다.
  static String _contextTime(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')} '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  /// 종합 상담에 담을 **모든 영역**의 최근 기록.
  ///
  /// 홈의 상담 단추가 쓰는 길입니다. 각 기록 화면의 아이콘을 없앴으므로
  /// 이 대화가 유일한 입구이고, 무엇을 물어도 답할 수 있어야 합니다.
  ///
  /// 영역마다 [overallLimit]건씩만 담습니다. 전부 넣으면 서버의 맥락 길이
  /// 상한(MAX_CONTEXT_CHARS, 기본 2000자)에 걸려 뒤쪽이 잘립니다 —
  /// 잘리면 어느 영역이 빠졌는지 아무도 모릅니다.
  ///
  /// 조회에 실패한 영역은 담기지 않습니다. 하나가 실패했다고 대화 전체를
  /// 막지는 않되, **실패했다는 사실은 함께 돌려줍니다** — 조용히 빠지면
  /// 모델이 "그 기록은 없다"고 답합니다.
  static Future<_Everything> _everything(String babyId) async {
    const domains = [
      AssessmentDomain.temperature,
      AssessmentDomain.feeding,
      AssessmentDomain.diaper,
      AssessmentDomain.sleep,
    ];

    final result = <MapEntry<String, List<String>>>[];
    var failed = false;

    void take(String label, List<String>? rows) {
      if (rows == null) {
        failed = true;
      } else if (rows.isNotEmpty) {
        result.add(MapEntry(label, rows));
      }
    }

    for (final d in domains) {
      take(d.label, await _recentFor(d, babyId, limit: overallLimit));
    }

    // 약·병원은 영역 enum이 없어 따로 담습니다.
    take('약·병원',
        await _recentFor(AssessmentDomain.overall, babyId, limit: overallLimit));

    return _Everything(byLabel: result, failed: failed);
  }

  /// 영역에 맞는 최근 기록을 문장으로 만듭니다.
  ///
  /// **조회에 실패하면 null입니다.** 빈 목록으로 돌려주면 "기록이 없다"와
  /// 같은 말이 되어, 모델이 없는 것을 없다고 확언하게 됩니다.
  static Future<List<String>?> _recentFor(
    AssessmentDomain domain,
    String babyId, {
    int? limit,
  }) async {
    final recentLimit = limit ?? ChatContext.recentLimit;
    try {
      switch (domain) {
        case AssessmentDomain.temperature:
          final rows =
              await TemperatureRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows)
              '${_contextTime(r.measuredAt)} · ${r.summary}',
          ];

        case AssessmentDomain.feeding:
          final rows =
              await FeedingRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows) '${_contextTime(r.fedAt)} · ${r.summary}',
          ];

        case AssessmentDomain.diaper:
          final rows =
              await DiaperRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows)
              '${_contextTime(r.recordedAt)} · ${r.summary}',
          ];

        case AssessmentDomain.sleep:
        case AssessmentDomain.noise:
          final rows =
              await SleepRecordService.loadRecent(babyId, limit: recentLimit);
          return [
            for (final r in rows)
              '${_contextTime(r.startedAt)} · ${r.summary}',
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
            // **약 이름과 용량은 보내지 않습니다.** 둘 다 보호자가 직접
            // 적는 자유 입력이고, 맥락에는 "답변할 때 참고하세요"가 붙습니다.
            // 모델에게는 약 이름·용량·복용법을 말하지 말라고 해 두었는데,
            // 그 값이 바로 옆에 놓여 있으면 "쓰고 계신 ○○를 계속…"처럼
            // 되짚는 순간 금지한 것이 그대로 나갑니다.
            // 병원 방문은 아래처럼 이미 라벨만 보내고 있습니다.
            for (final m in medications)
              '${_contextTime(m.takenAt)} · 약 ${m.reason.label}',
            for (final v in visits)
              '${_contextTime(v.visitedAt)} · 병원 ${v.reason.label}',
          ];
      }
    } catch (_) {
      // 조회 실패는 대화를 막을 이유가 아닙니다. 다만 "없다"고 말하지도
      // 않습니다 — 부르는 쪽이 그 차이를 화면에 전합니다.
      return null;
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

/// [ChatContext._everything]의 결과.
class _Everything {
  final List<MapEntry<String, List<String>>> byLabel;
  final bool failed;

  const _Everything({required this.byLabel, required this.failed});
}
