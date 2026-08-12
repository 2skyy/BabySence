import 'package:flutter/material.dart';

import '../advice/ask_button.dart';
import 'assessment/assessment.dart';

import '../../core/widgets/common_app_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'care/care_record_service.dart';
import 'temperature_record_service.dart';
import 'vaccination_readiness.dart';
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

  /// 접종 전에 진료실에서 말할 만한 최근 기록. 판정이 아닙니다.
  VaccinationReadiness _readiness = const VaccinationReadiness(notes: []);
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

      // 접종 전 확인 목록은 최근 기록에서 만듭니다. 실패해도 일정은 보여야
      // 하므로 따로 감쌉니다.
      var readiness = const VaccinationReadiness(notes: []);
      if (baby != null) {
        try {
          readiness = buildReadiness(
            temperatures: await TemperatureRecordService.loadRecent(baby.id),
            medications: await CareRecordService.loadMedications(baby.id),
            visits: await CareRecordService.loadVisits(baby.id),
          );
        } catch (e) {
          debugPrint('접종 전 확인 목록을 만들지 못했습니다: \$e');
        }
      }

      if (!mounted) return;
      setState(() {
        _baby = baby;
        _schedule = schedule;
        _readiness = readiness;
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
          _buildReadinessCard(),
          const SizedBox(height: 12),
          const AskButton(
            domain: AssessmentDomain.overall,
            label: '예방접종에 대해 물어보기',
          ),
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

  /// 접종 전에 진료실에서 말할 것들.
  ///
  /// **접종 가능 여부를 판정하지 않습니다.** 실제 기준인 "중등도~중증 급성
  /// 질환"은 진찰로 가리는 것이라 앱이 계산할 수 없습니다. 자세한 근거는
  /// vaccination_readiness.dart 참고.
  ///
  /// 대신 두 가지를 합니다.
  /// 1. 최근 기록을 모아 예진표의 "오늘 아픈 곳이 있습니까?"에 정확히 답하게
  /// 2. 미루지 않아도 되는 것들을 알려주기 — 세 지침 모두 불필요한 연기를
  ///    더 크게 경계합니다
  Widget _buildReadinessCard() {
    final notes = _readiness.notes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                '접종 전 확인',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (notes.isEmpty)
            Text(
              '최근 $readinessWindowDays일 안에 적어 둔 기록이 없습니다.\n'
              '기록이 없다고 접종해도 된다는 뜻은 아닙니다 — 아이 상태는 '
              '진료실에서 의사가 봅니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: secondaryTextColor,
              ),
            )
          else ...[
            Text(
              '최근 $readinessWindowDays일 기록입니다. 예진표의 "오늘 아픈 곳이 '
              '있습니까?"에 답할 때 참고하세요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '· ${n.text}',
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, color: context.colors.border),
          const SizedBox(height: 16),

          Text(
            '이런 것들은 접종을 미룰 이유가 아닙니다',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in notContraindications)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $item',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: secondaryTextColor,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            '접종을 늦추면 그동안 아이가 그 병에 걸릴 위험이 남습니다. '
            '미룰지 말지는 진료실에서 의사가 정합니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: secondaryTextColor,
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
