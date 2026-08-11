import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../detail/diaper_record_page.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_page.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_page.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_page.dart';
import '../detail/temperature_record_service.dart';
import '../detail/vaccination_page.dart';
import 'recent_records.dart';

/// 기록 탭 — 기록하러 가는 입구와 지금까지 남긴 기록을 한 곳에 둡니다.
///
/// 예전에는 홈 타일로만 각 기록 화면에 들어갈 수 있었고, 종류를 넘나드는
/// 목록은 아예 없었습니다. 수유 화면에서는 수유만, 배변 화면에서는 배변만
/// 보여 "어젯밤에 무슨 일이 있었는지"를 이어서 볼 수 없었습니다.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<RecentRecord> _records = const [];
  bool _loading = true;
  String? _error;

  /// 아이가 아직 없으면 기록 자체가 불가능합니다.
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
          _records = const [];
        });
        return;
      }

      // 네 종류를 동시에 부릅니다. 하나씩 기다리면 네 배로 느려집니다.
      final results = await Future.wait([
        FeedingRecordService.loadRecent(baby.id, limit: 30),
        DiaperRecordService.loadRecent(baby.id, limit: 30),
        SleepRecordService.loadRecent(baby.id, limit: 30),
        TemperatureRecordService.loadRecent(baby.id, limit: 30),
      ]);

      if (!mounted) return;
      setState(() {
        _hasBaby = true;
        _records = mergeRecentRecords(
          feedings: results[0] as List<FeedingRecord>,
          diapers: results[1] as List<DiaperRecord>,
          sleeps: results[2] as List<SleepRecord>,
          temperatures: results[3] as List<TemperatureRecord>,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '기록을 불러오지 못했습니다.');
      debugPrint('기록 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 기록 화면에서 돌아오면 목록을 다시 읽습니다.
  Future<void> _openRecord(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('기록'),
        centerTitle: true,
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _sectionTitle('무엇을 기록할까요'),
            const SizedBox(height: AppSpacing.md),
            _buildShortcuts(),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('최근 기록'),
            const SizedBox(height: AppSpacing.md),
            ..._buildTimeline(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );

  Widget _buildShortcuts() {
    final items = [
      (Icons.baby_changing_station, '수유', AppColors.primary,
          () => _openRecord(const FeedingRecordPage())),
      (Icons.opacity, '배변', Colors.amber.shade700,
          () => _openRecord(const DiaperRecordPage())),
      (Icons.bedtime, '수면', Colors.indigo,
          () => _openRecord(const SleepRecordPage())),
      (Icons.thermostat, '체온', Colors.red,
          () => _openRecord(const TemperatureRecordPage())),
      (Icons.vaccines, '예방접종', Colors.teal,
          () => _openRecord(const VaccinationPage())),
    ];

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: [
        for (final (icon, label, color, onTap) in items)
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTimeline() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null) {
      return [
        Text(
          _error!,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        TextButton(onPressed: _load, child: const Text('다시 시도')),
      ];
    }

    if (!_hasBaby) {
      return [
        Text(
          '아이 정보를 먼저 등록해 주세요.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ];
    }

    if (_records.isEmpty) {
      return [
        Text(
          '아직 남긴 기록이 없습니다.\n위에서 기록을 시작해 보세요.',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ];
    }

    final grouped = groupByDay(_records);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final day in days) ...[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            formatDayHeader(day),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        for (final record in grouped[day]!) _buildRow(record),
      ],
    ];
  }

  Widget _buildRow(RecentRecord record) {
    final (icon, color) = switch (record.kind) {
      RecordKind.feeding => (Icons.baby_changing_station, AppColors.primary),
      RecordKind.diaper => (Icons.opacity, Colors.amber.shade700),
      RecordKind.sleep => (Icons.bedtime, Colors.indigo),
      RecordKind.temperature => (Icons.thermostat, Colors.red),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.kind.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record.summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatTimeOfDay(record.at),
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
