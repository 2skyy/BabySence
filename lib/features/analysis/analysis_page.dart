import 'package:flutter/material.dart';

import '../../core/widgets/stale_notice.dart';
import '../../core/services/duration_text.dart';

import '../../core/services/refresh_signal.dart';

import '../../core/widgets/common_app_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../detail/assessment/assessment.dart';
import '../detail/assessment/assessment_service.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/growth/growth_record_page.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';
import 'weekly_summary.dart';

/// 분석 탭 — 쌓인 기록과 판정을 되돌아보는 곳.
///
/// 체온 화면이 판정을 assessments에 저장해 왔지만 다시 꺼내 보여주는 곳이
/// 없었습니다. 여기가 그 자리입니다.
///
/// 여기 숫자는 전부 실제 기록을 센 값입니다. 기록이 적으면 적은 대로
/// 보여줍니다 — 그럴듯한 값을 채우면 사용자가 자기 데이터로 오해합니다.
class AnalysisPage extends StatefulWidget {
  /// 이 탭이 다시 보일 때 울리는 신호. 없으면 처음 한 번만 읽습니다.
  ///
  /// [IndexedStack]이라 화면이 살아 있는 채로 숨겨져 initState가 한 번만
  /// 돕니다. 이게 없으면 방금 남긴 기록이 '없음'으로 보이고, 자정을 넘겨
  /// 돌아와도 어제 값이 그대로 있습니다.
  final RefreshSignal? refresh;

  const AnalysisPage({super.key, this.refresh});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  WeeklySummary? _summary;
  List<Assessment> _assessments = const [];
  bool _loading = true;
  String? _error;
  bool _hasBaby = false;

  @override
  void initState() {
    super.initState();
    _load();
    widget.refresh?.addListener(_load);
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_load);
    super.dispose();
  }

  /// 이 조회가 몇 번째인지.
  ///
  /// 탭을 다시 누르거나 앱이 앞으로 나오면 [RefreshSignal]이 울리는데,
  /// 앞 조회가 끝났는지는 보지 않습니다. 그래서 두 조회가 겹칠 수 있고,
  /// **늦게 온 실패가 방금 성공한 결과를 덮었습니다** — 최신 목록을 손에
  /// 쥔 채 '불러오지 못했습니다'만 남고, 스스로 낫지도 않았습니다.
  ///
  /// 마지막 조회의 결과만 반영합니다.
  int _loadGen = 0;

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final baby = await BabyService.loadCurrent();
      if (baby == null) {
        if (!mounted) return;
        setState(() {
          _hasBaby = false;
          _summary = null;
          _assessments = const [];
        });
        return;
      }

      // **창을 조회로 표현합니다.** 예전에는 "7일치를 넉넉히 덮도록
      // 100건씩" 읽었는데, 신생아기처럼 하루 열 번 넘게 기록하면 7일이
      // 100건을 넘습니다. 그러면 '수유 100회 · 하루 평균 14.3회'에서
      // 포화되고, 화면에는 잘렸다는 표시가 없습니다.
      //
      // WeeklySummary가 세는 창과 같은 기간을 넘깁니다.
      final today = DateTime.now();
      final since = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: WeeklySummary.days - 1));

      final results = await Future.wait([
        FeedingRecordService.loadRecent(baby.id, since: since, limit: 500),
        DiaperRecordService.loadRecent(baby.id, since: since, limit: 500),
        SleepRecordService.loadRecent(baby.id, since: since, limit: 500),
        TemperatureRecordService.loadRecent(baby.id, since: since, limit: 500),
        AssessmentService.loadRecent(babyId: baby.id, limit: 10),
      ]);

      if (!mounted || gen != _loadGen) return;
      setState(() {
        _hasBaby = true;
        // 성공했으면 앞선 실패 표시를 지웁니다.
        _error = null;
        _summary = WeeklySummary.from(
          feedings: results[0] as List<FeedingRecord>,
          diapers: results[1] as List<DiaperRecord>,
          sleeps: results[2] as List<SleepRecord>,
          temperatures: results[3] as List<TemperatureRecord>,
        );
        _assessments = results[4] as List<Assessment>;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _error = '분석을 불러오지 못했습니다.');
      debugPrint('분석 조회 실패: $e');
    } finally {
      if (mounted && gen == _loadGen) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(
        title: '분석',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ..._buildBody(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    // 이미 요약이 있으면 스피너로 갈아끼우지 않습니다.
    //
    // 갈아끼우면 화면 높이가 0으로 줄고, 되돌아올 때 스크롤이 맨 위로
    // 튑니다(RangeMaintainingScrollPhysics가 위치를 clamp합니다). 탭을
    // 오갈 때마다 보던 자리를 잃었습니다.
    if (_loading && _summary == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    // 실패했더라도 손에 든 것이 있으면 그것부터 보여줍니다. 목록을
    // 지우고 오류만 남기면, 방금까지 보던 기록이 사라집니다.
    if (_error != null && _summary == null) {
      return [
        Text(
          _error!,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        TextButton(onPressed: _load, child: const Text('다시 시도')),
      ];
    }

    // 낡았을 수 있다는 사실은 감추지 않습니다.
    final stale = _error == null
        ? const <Widget>[]
        : [StaleNotice(message: _error!, onRetry: _load)];

    if (!_hasBaby) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            '아이 정보를 먼저 등록해 주세요.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ),
      ];
    }

    return [
      ...stale,
      _sectionTitle('최근 7일'),
      const SizedBox(height: AppSpacing.md),
      _buildWeeklyCard(),
      const SizedBox(height: AppSpacing.xl),
      _sectionTitle('판정 기록'),
      const SizedBox(height: AppSpacing.md),
      ..._buildAssessments(),
      const SizedBox(height: AppSpacing.xl),
      _sectionTitle('성장'),
      const SizedBox(height: AppSpacing.md),
      _buildGrowthLink(),
      const SizedBox(height: AppSpacing.xl),
      // 이 화면은 판정 이력을 모아 보여주므로 고지가 필요합니다.
      const MedicalDisclaimer(),
    ];
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );

  Widget _buildWeeklyCard() {
    final s = _summary!;

    if (s.isEmpty) {
      return _card(
        child: Text(
          '최근 7일 동안 남긴 기록이 없습니다.\n기록을 남기면 여기에 모아 보여드립니다.',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      );
    }

    return _card(
      child: Column(
        children: [
          _statRow(
            icon: Icons.baby_changing_station,
            color: AppColors.primary,
            label: '수유',
            value: '${s.feedingCount}회',
            // 기록이 없으면 '하루 평균 0.0회 · 기록한 0일 기준' 대신
            // 그냥 없다고 적습니다. 나눌 것이 없는데 평균을 적는 것은
            // 숫자를 지어내는 쪽에 가깝습니다.
            detail: s.feedingDays == 0
                ? '아직 기록이 없습니다'
                : '하루 평균 ${s.feedingPerDay.toStringAsFixed(1)}회'
                    ' · ${WeeklySummary.basis(s.feedingDays)}',
          ),
          const Divider(height: AppSpacing.xl),
          _statRow(
            icon: Icons.opacity,
            color: Colors.amber.shade700,
            label: '배변',
            value: '${s.diaperCount}회',
            detail: s.diaperDays == 0
                ? '아직 기록이 없습니다'
                : '하루 평균 ${s.diaperPerDay.toStringAsFixed(1)}회'
                    ' · ${WeeklySummary.basis(s.diaperDays)}',
          ),
          const Divider(height: AppSpacing.xl),
          _statRow(
            icon: Icons.bedtime,
            color: Colors.indigo,
            label: '수면',
            value: s.completedSleepCount == 0
                ? '기록 없음'
                : formatDuration(s.sleepTotal),
            // 측정 중인 수면은 길이를 모르므로 합계에서 빠집니다. 숫자가
            // 실제보다 작을 수 있다는 걸 숨기지 않습니다.
            detail: s.completedSleepCount == 0
                ? '끝난 수면 기록이 필요합니다'
                : '하루 평균 ${formatDuration(s.sleepPerDay)}'
                    ' · ${WeeklySummary.basis(s.sleepDays)}'
                    ' · 끝난 수면 ${s.completedSleepCount}건',
          ),
          const Divider(height: AppSpacing.xl),
          _statRow(
            icon: Icons.thermostat,
            color: Colors.red,
            label: '최고 체온',
            value: s.highestTemperature == null
                ? '기록 없음'
                : '${s.highestTemperature!.toStringAsFixed(1)}°C',
            detail: s.highestTemperature == null ? '체온을 기록해 보세요' : '7일 중 가장 높은 값',
          ),
        ],
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String detail,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAssessments() {
    if (_assessments.isEmpty) {
      return [
        _card(
          child: Text(
            '아직 판정이 없습니다.\n체온을 기록하면 연령대별 기준으로 판정해 드립니다.',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
      ];
    }

    return [
      for (final a in _assessments)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _card(child: _assessmentBody(a)),
        ),
    ];
  }

  Widget _assessmentBody(Assessment a) {
    final color = switch (a.level) {
      AssessmentLevel.normal => AppColors.primary,
      AssessmentLevel.caution => Colors.orange.shade700,
      AssessmentLevel.consult => AppColors.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                // levelLabel을 써야 소음이 '개선 권장'으로 나옵니다.
                // level.label을 쓰면 "소음 · 상담 권장"이 되어, 소음 때문에
                // 병원에 가라는 말로 읽힙니다.
                '${a.domain.label} · ${a.levelLabel}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const Spacer(),
            if (a.assessedAt != null)
              Text(
                _formatDate(a.assessedAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          a.guideText,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Widget _buildGrowthLink() {
    return _card(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GrowthRecordPage()),
        );
        if (mounted) _load();
      },
      child: Row(
        children: [
          Icon(Icons.show_chart, color: Colors.blue),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '성장 곡선',
                  style: TextStyle(color: context.colors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'WHO 표준과 견줘 봅니다',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textSecondary),
        ],
      ),
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
    );
  }
}
