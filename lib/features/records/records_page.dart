import 'package:flutter/material.dart';

import '../../core/widgets/common_app_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/baby_service.dart';
import '../detail/care/care_record_service.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/growth/growth_record.dart';
import '../detail/growth/growth_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';
import 'recent_records.dart';

/// 기록 탭 — **지금까지 남긴 기록만** 시간순으로 봅니다.
///
/// 수유 화면에서는 수유만, 배변 화면에서는 배변만 보여 "어젯밤에 무슨 일이
/// 있었는지"를 이어서 볼 수 없습니다. 그것을 잇는 자리입니다.
///
/// 기록하러 들어가는 입구는 두지 않습니다. 예전에는 여기에도 5칸 격자가
/// 있었는데 홈의 9칸과 겹쳤고, 홈보다 적어서 여기서 기록한다고 배운 사람은
/// 성장·약병원을 찾지 못했습니다. 입구는 홈 한 곳입니다.
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

      // 동시에 부릅니다. 하나씩 기다리면 종류 수만큼 느려집니다.
      final results = await Future.wait([
        FeedingRecordService.loadRecent(baby.id, limit: 30),
        DiaperRecordService.loadRecent(baby.id, limit: 30),
        SleepRecordService.loadRecent(baby.id, limit: 30),
        TemperatureRecordService.loadRecent(baby.id, limit: 30),
        GrowthRecordService.loadRecords(baby.id),
        CareRecordService.loadMedications(baby.id, limit: 30),
        CareRecordService.loadVisits(baby.id, limit: 30),
      ]);

      if (!mounted) return;
      setState(() {
        _hasBaby = true;
        _records = mergeRecentRecords(
          feedings: results[0] as List<FeedingRecord>,
          diapers: results[1] as List<DiaperRecord>,
          sleeps: results[2] as List<SleepRecord>,
          temperatures: results[3] as List<TemperatureRecord>,
          growths: results[4] as List<GrowthRecord>,
          medications: results[5] as List<MedicationRecord>,
          visits: results[6] as List<HospitalVisit>,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(title: '기록'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ..._buildTimeline(),
            const SizedBox(height: 100),
          ],
        ),
      ),
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
          '아직 남긴 기록이 없습니다.\n홈 화면에서 기록을 시작해 보세요.',
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
    // 홈 타일과 같은 아이콘·색을 씁니다. 다르면 같은 기록이 화면마다
    // 다른 것처럼 보입니다.
    final (icon, color) = switch (record.kind) {
      RecordKind.feeding => (Icons.baby_changing_station, AppColors.primary),
      RecordKind.diaper => (Icons.opacity, Colors.amber.shade700),
      RecordKind.sleep => (Icons.bedtime, Colors.indigo),
      RecordKind.temperature => (Icons.thermostat, Colors.red),
      RecordKind.growth => (Icons.show_chart, Colors.blue),
      RecordKind.medication => (Icons.medication_outlined, Colors.redAccent),
      RecordKind.hospital => (Icons.local_hospital_outlined, Colors.redAccent),
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
          // 성장은 잰 시각을 모릅니다(date 컬럼). '오전 12:00'을 붙이면
          // 자정에 쟀다는 뜻이 되므로 비웁니다.
          if (record.hasTime)
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
