import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/baby_service.dart';
import '../../../core/services/growth_calculator.dart';
import '../../../core/widgets/common_app_bar.dart';
import '../../../core/widgets/common_button.dart';
import '../../../routes/app_routes.dart';
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
      appBar: const CommonAppBar(title: '성장 기록'),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
        ],
      ),
    );
  }

  bool _savingRecord = false;

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
      _heightController.clear();
      _weightController.clear();
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
        icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
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

    Color bandColor(double z) => z == 0 ? AppColors.textSecondary : AppColors.border;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 24,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 6,
                getTitlesWidget: (value, meta) => Text('${value.toInt()}개월', style: const TextStyle(fontSize: 10)),
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
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
