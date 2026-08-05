import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
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
  const AnalysisPage({super.key});

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
  }

  Future<void> _load() async {
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

      // 7일치를 넉넉히 덮도록 100건씩 봅니다.
      final results = await Future.wait([
        FeedingRecordService.loadRecent(baby.id, limit: 100),
        DiaperRecordService.loadRecent(baby.id, limit: 100),
        SleepRecordService.loadRecent(baby.id, limit: 100),
        TemperatureRecordService.loadRecent(baby.id, limit: 100),
        AssessmentService.loadRecent(babyId: baby.id, limit: 10),
      ]);

      if (!mounted) return;
      setState(() {
        _hasBaby = true;
        _summary = WeeklySummary.from(
          feedings: results[0] as List<FeedingRecord>,
          diapers: results[1] as List<DiaperRecord>,
          sleeps: results[2] as List<SleepRecord>,
          temperatures: results[3] as List<TemperatureRecord>,
        );
        _assessments = results[4] as List<Assessment>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '분석을 불러오지 못했습니다.');
      debugPrint('분석 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('분석'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null) {
      return [
        Text(
          _error!,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        TextButton(onPressed: _load, child: const Text('다시 시도')),
      ];
    }

    if (!_hasBaby) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            '아이 정보를 먼저 등록해 주세요.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ];
    }

    return [
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
    ];
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _buildWeeklyCard() {
    final s = _summary!;

    if (s.isEmpty) {
      return _card(
        child: const Text(
          '최근 7일 동안 남긴 기록이 없습니다.\n기록을 남기면 여기에 모아 보여드립니다.',
          style: TextStyle(
            color: AppColors.textSecondary,
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
            detail: '하루 평균 ${s.feedingPerDay.toStringAsFixed(1)}회',
          ),
          const Divider(height: AppSpacing.xl),
          _statRow(
            icon: Icons.opacity,
            color: Colors.amber.shade700,
            label: '배변',
            value: '${s.diaperCount}회',
            detail: '하루 평균 ${(s.diaperCount / WeeklySummary.days).toStringAsFixed(1)}회',
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
                : '하루 평균 ${formatDuration(s.sleepPerDay)} · 끝난 수면 ${s.completedSleepCount}건 기준',
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAssessments() {
    if (_assessments.isEmpty) {
      return [
        _card(
          child: const Text(
            '아직 판정이 없습니다.\n체온을 기록하면 연령대별 기준으로 판정해 드립니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
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
                '${a.domain.label} · ${a.level.label}',
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
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          a.guideText,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textPrimary,
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
      child: const Row(
        children: [
          Icon(Icons.show_chart, color: Colors.blue),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '성장 곡선',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'WHO 표준과 견줘 봅니다',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
      color: AppColors.surface,
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
