import 'package:flutter/material.dart';

import '../../core/widgets/common_app_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'vaccination_service.dart';

class VaccinationPage extends StatefulWidget {
  const VaccinationPage({super.key});

  @override
  State<VaccinationPage> createState() => _VaccinationPageState();
}

class _VaccinationPageState extends State<VaccinationPage> {
  static const Color primaryColor = Color(0xFF14B8A6);
  Color get backgroundColor => context.colors.background;
  Color get surfaceColor => context.colors.surface;
  Color get textColor => context.colors.textPrimary;
  Color get secondaryTextColor => context.colors.textSecondary;

  Baby? _baby;
  List<VaccinationStatus> _schedule = [];
  bool _loading = true;
  String? _error;

  /// 지금 저장 중인 백신 id. 중복 탭을 막고 그 항목만 비활성화합니다.
  int? _updatingVaccineId;

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
      final schedule = baby == null
          ? <VaccinationStatus>[]
          : await VaccinationService.loadSchedule(
              babyId: baby.id,
              birthDate: baby.birthDate,
            );

      if (!mounted) return;
      setState(() {
        _baby = baby;
        _schedule = schedule;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '접종 일정을 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
  }

  /// 항목을 눌러 접종 완료 / 취소를 토글합니다.
  Future<void> _toggle(VaccinationStatus status) async {
    final baby = _baby;
    if (baby == null) return;

    setState(() => _updatingVaccineId = status.vaccine.id);
    try {
      if (status.isDone) {
        await VaccinationService.unmarkVaccinated(
          babyId: baby.id,
          vaccineId: status.vaccine.id,
        );
      } else {
        await VaccinationService.markVaccinated(
          babyId: baby.id,
          vaccineId: status.vaccine.id,
          vaccinatedOn: DateTime.now(),
          scheduledOn: status.scheduledOn,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장하지 못했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingVaccineId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CommonAppBar(title: '예방접종'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildMessage(_error!, showRetry: true)
              : _baby == null
                  ? _buildMessage('접종 일정을 보려면 아이 정보가 필요해요.')
                  : _buildContent(),
    );
  }

  Widget _buildMessage(String message, {bool showRetry = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (showRetry) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final done = _schedule.where((s) => s.isDone).toList();
    final upcoming = _schedule.where((s) => !s.isDone).toList()
      ..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildNextVaccinationCard(upcoming.isEmpty ? null : upcoming.first),
          const SizedBox(height: 24),
          _buildProgressCard(done.length, _schedule.length),
          const SizedBox(height: 24),
          if (done.isNotEmpty) ...[
            _buildSectionTitle('완료한 접종 (${done.length})'),
            const SizedBox(height: 12),
            ...done.map(_buildVaccinationItem),
            const SizedBox(height: 24),
          ],
          _buildSectionTitle('예정된 접종 (${upcoming.length})'),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '모든 접종을 완료했습니다.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            ...upcoming.map(_buildVaccinationItem),
        ],
      ),
    );
  }

  Widget _buildNextVaccinationCard(VaccinationStatus? next) {
    final now = DateTime.now();

    final String title;
    final String detail;
    if (next == null) {
      title = '없음';
      detail = '표준 일정을 모두 마쳤습니다';
    } else {
      title = next.vaccine.name;
      // 날짜만 비교합니다. 시각까지 넣으면 같은 날이 D-1로 보입니다.
      final today = DateTime(now.year, now.month, now.day);
      final days = next.scheduledOn.difference(today).inDays;
      final dday = days == 0
          ? '오늘'
          : days > 0
              ? 'D-$days'
              : '${-days}일 지남';
      detail = '${next.vaccine.recommendedAgeLabel} 시기 · $dday';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.vaccines, color: primaryColor, size: 36),
          const SizedBox(height: 16),
          Text(
            '다음 접종',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(int done, int total) {
    final percent = total == 0 ? 0 : (done / total * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE0F2F1),
            child: Icon(Icons.check, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '접종 진행률',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done / $total 완료',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              color: primaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildVaccinationItem(VaccinationStatus status) {
    final isCompleted = status.isDone;
    final isUpdating = _updatingVaccineId == status.vaccine.id;
    final isOverdue = status.isOverdue(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? primaryColor.withValues(alpha: 0.3)
              : isOverdue
                  ? const Color(0xFFFCA5A5)
                  : context.colors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        // 저장 중에는 다시 누를 수 없게 합니다.
        onTap: isUpdating ? null : () => _toggle(status),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isUpdating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? primaryColor : secondaryTextColor,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.vaccine.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCompleted
                          ? '${status.vaccine.recommendedAgeLabel} · ${_formatDate(status.vaccinatedOn!)} 접종'
                          : '${status.vaccine.recommendedAgeLabel} · 예정 ${_formatDate(status.scheduledOn)}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isCompleted
                    ? '완료'
                    : isOverdue
                        ? '지남'
                        : '예정',
                style: TextStyle(
                  color: isCompleted
                      ? primaryColor
                      : isOverdue
                          ? const Color(0xFFDC2626)
                          : secondaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
