import 'package:flutter/material.dart';

import '../../advice/ask_action.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/baby_service.dart';
import '../../../core/services/growth_calculator.dart';
import '../../../core/widgets/common_app_bar.dart';
import '../../../core/widgets/common_button.dart';
import '../../../core/widgets/medical_disclaimer.dart';
import '../../../routes/app_routes.dart';
import '../assessment/assessment.dart';
import '../assessment/assessment_service.dart';
import '../assessment/growth_rules.dart';
import 'growth_chart_axis.dart';
import 'growth_record.dart';
import 'growth_repository.dart';

class GrowthRecordPage extends StatefulWidget {
  /// 데이터 접근 경로. 기본값은 Supabase이고, 테스트에서 가짜 구현을 넣습니다.
  final GrowthRepository repository;

  const GrowthRecordPage({
    super.key,
    this.repository = const SupabaseGrowthRepository(),
  });

  @override
  State<GrowthRecordPage> createState() => _GrowthRecordPageState();
}

class _GrowthRecordPageState extends State<GrowthRecordPage> {
  Baby? _baby;
  List<GrowthRecord> _records = [];
  bool _loading = true;
  String? _error;

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
      final baby = await widget.repository.loadBaby();
      final records = baby == null
          ? <GrowthRecord>[]
          : await widget.repository.loadRecords(baby.id);

      if (!mounted) return;
      setState(() {
        _baby = baby;
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
  }

  double _ageInMonths(DateTime birthDate, DateTime date) {
    return date.difference(birthDate).inDays / 30.4375;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '성장 기록',
        actions: [
          AskAction(
            domain: AssessmentDomain.growth,
            assessment: _lastAssessment,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(_error!)
              : _baby == null
                  ? _buildProfileSetup()
                  : _buildContent(_baby!),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          CommonButton(text: '다시 시도', onPressed: _load),
        ],
      ),
    );
  }

  /// 아이가 아직 없을 때. 등록 화면은 온보딩([AppRoutes.onboarding]) 한 곳에만
  /// 두고, 여기서는 그쪽으로 보냅니다.
  Widget _buildProfileSetup() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'WHO 성장 표준과 비교하려면\n아이의 정보가 필요해요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xxl),
          CommonButton(
            text: '아이 정보 등록하기',
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.onboarding);
              // 등록을 마치고 돌아오면 다시 읽어옵니다.
              if (mounted) _load();
            },
          ),
        ],
      ),
    );
  }

  // --- 기록 입력 + 차트 + 이력 ---

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime _recordDate = DateTime.now();

  Widget _buildContent(Baby baby) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddRecordCard(baby),
          const SizedBox(height: AppSpacing.xxl),
          Text('몸무게 (kg)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _buildChart(baby, isWeight: true),
          const SizedBox(height: AppSpacing.xxl),
          Text('키 (cm)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _buildChart(baby, isWeight: false),
          const SizedBox(height: AppSpacing.xxl),
          Text('기록 이력', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ..._records.reversed.map((r) => _buildRecordTile(r)),
        ],
      ),
    );
  }

  Widget _buildAddRecordCard(Baby baby) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _recordDate,
                firstDate: baby.birthDate,
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _recordDate = picked);
            },
            child: Text('측정일: ${_formatDate(_recordDate)}'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '키 (cm)'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '몸무게 (kg)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CommonButton(
            text: '기록 추가',
            isLoading: _savingRecord,
            onPressed: () => _handleAddRecord(baby),
          ),
          if (_lastAssessment != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildAssessmentCard(_lastAssessment!),
            const SizedBox(height: AppSpacing.md),
            // 판정을 보여주는 자리에는 반드시 함께 둡니다.
            const MedicalDisclaimer(),
          ],
        ],
      ),
    );
  }

  /// WHO 성장 표준 판정 결과.
  Widget _buildAssessmentCard(Assessment assessment) {
    final color = switch (assessment.level) {
      AssessmentLevel.normal => AppColors.primary,
      AssessmentLevel.caution => Colors.orange.shade700,
      AssessmentLevel.consult => AppColors.error,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assessment.levelLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            assessment.guideText,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  bool _savingRecord = false;

  /// 방금 저장한 기록의 판정. 없으면 아직 판정하지 않은 상태입니다.
  Assessment? _lastAssessment;

  Future<void> _handleAddRecord(Baby baby) async {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    if (height == null && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('키 또는 몸무게 중 하나는 입력해주세요.')),
      );
      return;
    }

    setState(() => _savingRecord = true);
    try {
      await widget.repository.saveRecord(
        babyId: baby.id,
        date: _recordDate,
        heightCm: height,
        weightKg: weight,
      );

      // WHO 성장 표준으로 판정하고 결과를 남깁니다.
      // 판정은 앱에서 계산하므로 저장이 실패해도 안내는 보여줄 수 있습니다.
      final assessment = GrowthRules.assess(
        sex: baby.sex,
        // 차트와 같은 값을 씁니다. 만 개월로 내리면 판정이 한 달 어린
        // 기준으로 계산됩니다.
        ageInMonths: _ageInMonths(baby.birthDate, _recordDate),
        weightKg: weight,
        heightCm: height,
      );

      if (assessment != null) {
        try {
          await AssessmentService.save(babyId: baby.id, assessment: assessment);
        } catch (e) {
          // 판정 저장 실패가 성장 기록 자체를 무효로 만들지는 않습니다.
          debugPrint('성장 판정 저장 실패: $e');
        }
      }

      _heightController.clear();
      _weightController.clear();
      if (mounted) setState(() => _lastAssessment = assessment);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록을 저장하지 못했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _savingRecord = false);
    }
  }

  Widget _buildRecordTile(GrowthRecord record) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_formatDate(record.date)),
      subtitle: Text([
        if (record.heightCm != null) '키 ${record.heightCm!.toStringAsFixed(1)}cm',
        if (record.weightKg != null) '몸무게 ${record.weightKg!.toStringAsFixed(1)}kg',
      ].join(' · ')),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: context.colors.textSecondary),
        onPressed: () async {
          try {
            await widget.repository.deleteRecord(record.id);
            await _load();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('삭제하지 못했습니다. $e')),
            );
          }
        },
      ),
    );
  }

  Widget _buildChart(Baby baby, {required bool isWeight}) {
    final months = List<int>.generate(25, (i) => i);

    List<FlSpot> percentileLine(double z) {
      return months
          .map((m) => FlSpot(
                m.toDouble(),
                isWeight
                    ? GrowthCalculator.weightAtZ(baby.sex, m.toDouble(), z)
                    : GrowthCalculator.lengthAtZ(baby.sex, m.toDouble(), z),
              ))
          .toList();
    }

    final childSpots = _records
        .where((r) => isWeight ? r.weightKg != null : r.heightCm != null)
        .map((r) => FlSpot(
              _ageInMonths(baby.birthDate, r.date).clamp(0, 24),
              (isWeight ? r.weightKg : r.heightCm)!,
            ))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    Color bandColor(double z) => z == 0 ? context.colors.textSecondary : context.colors.border;

    // 세로축. 몸무게는 kg, 키는 cm라 눈금 간격이 다릅니다.
    final axis = ChartAxis.fit(
      [
        for (final z in GrowthPercentiles.standard)
          ...percentileLine(z).map((s) => s.y),
        ...childSpots.map((s) => s.y),
      ],
      step: isWeight ? 3.0 : 10.0,
    );

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 24,
          minY: axis.min,
          maxY: axis.max,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 6,
                reservedSize: 24,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  // 0개월과 24개월 라벨이 양 끝에서 잘리지 않게 띄웁니다.
                  space: 6,
                  child: Text(
                    '${value.toInt()}개월',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: axis.step,
                // 소수점이 딸린 실수를 그대로 찍지 않습니다.
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 6,
                  child: Text(
                    axis.label(value),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: axis.step,
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            for (final z in GrowthPercentiles.standard)
              LineChartBarData(
                spots: percentileLine(z),
                isCurved: true,
                barWidth: z == 0 ? 1.5 : 1,
                dotData: const FlDotData(show: false),
                color: bandColor(z),
              ),
            LineChartBarData(
              spots: childSpots,
              isCurved: false,
              barWidth: 3,
              color: AppColors.primary,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}
