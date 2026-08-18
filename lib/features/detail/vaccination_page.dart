import 'dart:async';
import 'package:flutter/material.dart';


import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/confirm_dialog.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'care/care_record_service.dart';
import 'temperature_record_service.dart';
import 'vaccination_readiness.dart';
import 'vaccination_service.dart';
import '../vaccination_reminder/vaccination_reminder_service.dart';
import '../vaccination_reminder/vaccination_reminder_settings.dart';

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

  /// 최근 기록을 못 읽었는지. 못 읽은 것과 "기록이 없는 것"은 다릅니다 —
  /// 빈 카드를 그냥 보여주면 확인했는데 아무것도 없었다는 뜻이 됩니다.
  bool _readinessFailed = false;
  bool _loading = true;
  String? _error;

  /// 지금 저장 중인 백신 id. 중복 탭을 막고 그 항목만 비활성화합니다.
  int? _updatingVaccineId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 지금 걸려 있는 알림 설정. 일정을 읽을 때 함께 읽습니다.
  VaccinationReminderSettings _reminder = const VaccinationReminderSettings();

  /// 알림을 다시 겁니다. 실패는 서비스 안에서 삼키므로 화면은 그대로입니다.
  Future<void> _rescheduleReminders(List<VaccinationStatus> schedule) async {
    final settings = await VaccinationReminderSettings.load();
    if (mounted) setState(() => _reminder = settings);
    await VaccinationReminderService.reschedule(schedule, settings: settings);
  }

  /// 설정을 바꾸고 곧바로 다시 겁니다.
  Future<void> _applyReminder(VaccinationReminderSettings settings) async {
    setState(() => _reminder = settings);
    await settings.save();
    await VaccinationReminderService.reschedule(_schedule, settings: settings);
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
      var readinessFailed = false;
      if (baby != null) {
        try {
          // 서로 독립이라 순서대로 기다릴 이유가 없습니다.
          // 확인 목록이 보는 창(3일) 전체를 읽습니다. 기본 20건에만 기대면
          // 열이 나서 자주 잰 아이일수록 창 앞쪽(첫날 고열)이 빠지는데,
          // 하필 진료실에서 가장 말할 가치가 있는 값입니다. 앱 자체가 2시간
          // 간격 재측정을 권하므로 흔한 상황입니다.
          final since = DateTime.now()
              .subtract(const Duration(days: readinessWindowDays));

          final sources = await Future.wait([
            TemperatureRecordService.loadRecent(baby.id,
                since: since, limit: 200),
            CareRecordService.loadMedications(baby.id,
                since: since, limit: 200),
            CareRecordService.loadVisits(baby.id, since: since, limit: 200),
          ]);
          readiness = buildReadiness(
            temperatures: sources[0] as List<TemperatureRecord>,
            medications: sources[1] as List<MedicationRecord>,
            visits: sources[2] as List<HospitalVisit>,
          );
        } catch (e) {
          readinessFailed = true;
          debugPrint('접종 전 확인 목록을 만들지 못했습니다: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _baby = baby;
        _schedule = schedule;
        _readiness = readiness;
        _readinessFailed = readinessFailed;
        _loading = false;
      });

      // 일정을 읽은 김에 알림을 다시 겁니다. 접종을 마치거나 날짜가 바뀌면
      // 예전 예약이 남으면 안 되고, 이 화면이 최신 일정을 아는 유일한 곳입니다.
      // 기다리지 않습니다 -- 알림 예약 때문에 화면이 늦게 뜰 이유가 없습니다.
      unawaited(_rescheduleReminders(schedule));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '접종 일정을 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
  }

  /// 항목을 눌렀을 때.
  ///
  /// **완료한 접종은 눌러도 사라지지 않습니다.** 예전에는 같은 탭이 곧바로
  /// DELETE를 보내, 확인 창도 없이 '예정'으로 되돌아갔습니다. 다시 눌러
  /// 되살리면 접종일이 **오늘**로 바뀌어, 실제로 맞은 날이 사라졌습니다.
  /// 목록 전체가 InkWell이라 스크롤 중에도 눌렸습니다.
  ///
  /// 접종 기록은 "언제 맞았더라"를 확인하려고 남기는 것이라, 지우는 쪽보다
  /// **날짜를 고치는 쪽**이 기본이어야 합니다.
  Future<void> _onTap(VaccinationStatus status) async {
    if (status.isDone) {
      await _editVaccinatedOn(status);
      return;
    }
    await _markDone(status, DateTime.now());
  }

  /// 완료한 접종의 날짜를 고칩니다. 되돌리기는 여기서만 할 수 있습니다.
  Future<void> _editVaccinatedOn(VaccinationStatus status) async {
    // **범위 안으로 밀어 넣습니다.**
    //
    // initialDate는 DB에 남은 접종일, firstDate는 지금의 생년월일입니다.
    // 생년월일을 더 늦은 날로 고치면(마이페이지에서 오타를 바로잡는 흔한
    // 일입니다) 접종일이 그보다 앞서게 되고, showDatePicker는 그 조합에서
    // 단정에 걸립니다. 크래시는 아니지만 **아무 일도 일어나지 않습니다** —
    // 눌러도 반응이 없고 콘솔에만 찍혀, 사용자는 화면이 고장 난 줄 압니다.
    final first = _baby?.birthDate ?? DateTime(2000);
    final last = DateTime.now();
    final recorded = status.vaccinatedOn!;
    final initial = recorded.isBefore(first)
        ? first
        : recorded.isAfter(last)
            ? last
            : recorded;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: '${status.vaccine.name} 접종일',
      confirmText: '저장',
      cancelText: '닫기',
    );
    if (picked == null || !mounted) return;
    await _markDone(status, picked);
  }

  /// 잘못 표시한 접종을 되돌립니다. **길게 눌러야** 닿습니다.
  Future<void> _undo(VaccinationStatus status) async {
    final baby = _baby;
    if (baby == null) return;

    final ok = await confirmDestructive(
      context,
      title: '접종 기록을 지울까요?',
      body: '${status.vaccine.name}\n'
          '${_formatDate(status.vaccinatedOn!)} 접종으로 기록돼 있습니다.\n\n'
          '지우면 다시 \'예정\'으로 돌아가고, 맞은 날짜는 사라집니다.',
    );
    if (!ok) return;

    setState(() => _updatingVaccineId = status.vaccine.id);
    try {
      await VaccinationService.unmarkVaccinated(
        babyId: baby.id,
        vaccineId: status.vaccine.id,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('지우지 못했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingVaccineId = null);
    }
  }

  Future<void> _markDone(VaccinationStatus status, DateTime on) async {
    final baby = _baby;
    if (baby == null) return;

    setState(() => _updatingVaccineId = status.vaccine.id);
    try {
      await VaccinationService.markVaccinated(
        babyId: baby.id,
        vaccineId: status.vaccine.id,
        vaccinatedOn: on,
        scheduledOn: status.scheduledOn,
      );
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
      appBar: const CommonAppBar(
        title: '예방접종',
      ),
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
          _buildReminderCard(),
          const SizedBox(height: 24),
          _buildReadinessCard(),
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


  /// 알림 설정 카드.
  ///
  /// **판정이 아니라 예약입니다.** 켜면 표준 일정의 예정일에서 고른 만큼
  /// 당긴 날 오전 9시에 알립니다. 접종 가능 여부는 말하지 않습니다.
  Widget _buildReminderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '접종일 알림',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Switch(
                value: _reminder.notify,
                activeThumbColor: primaryColor,
                onChanged: (on) =>
                    _applyReminder(_reminder.copyWith(notify: on)),
              ),
            ],
          ),
          if (_reminder.notify) ...[
            const SizedBox(height: 4),
            Text(
              '예정일 기준 언제 알릴까요?',
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final days
                    in VaccinationReminderSettings.selectableDaysBefore)
                  ChoiceChip(
                    label: Text(formatDaysBefore(days)),
                    selected: _reminder.daysBefore == days,
                    onSelected: (_) =>
                        _applyReminder(_reminder.copyWith(daysBefore: days)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              // 정확한 알람 권한을 요구하지 않는 대신 몇 분 늦을 수 있습니다.
              // 미리 말해 두지 않으면 고장으로 읽힙니다.
              '오전 9시에 알려드리며, 기기 상태에 따라 조금 늦을 수 있어요.',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          ],
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

          if (_readinessFailed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '최근 기록을 불러오지 못했습니다. 아래 목록이 비어 있는 것은 '
                    '기록이 없어서가 아닙니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ],
            )
          else if (notes.isEmpty)
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
        onTap: isUpdating ? null : () => _onTap(status),
        // 잘못 표시한 접종을 되돌리는 길. 완료 항목에만 있습니다.
        // 탭에 두지 않는 이유는 스크롤 중에 눌리기 때문입니다.
        onLongPress:
            isUpdating || !isCompleted ? null : () => _undo(status),
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
                          ? '${status.vaccine.recommendedAgeLabel} · ${_formatDate(status.vaccinatedOn!)} 접종\n눌러서 날짜 수정 · 길게 눌러 되돌리기'
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
