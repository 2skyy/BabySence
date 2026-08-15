import 'package:flutter/material.dart';

import '../../../core/widgets/missing_baby.dart';


import '../../../core/constants/app_colors.dart';
import '../../../core/services/baby_service.dart';
import '../../../core/widgets/common_app_bar.dart';
import '../widgets/record_save_button.dart';
import '../widgets/record_history.dart';
import '../widgets/record_time_field.dart';
import 'care_record_service.dart';

/// 약 복용과 병원 방문을 남기는 화면.
///
/// 논문 3-2절 ⑥. 두 기록을 한 화면에 둔 이유는 대개 같은 일에서 나오기
/// 때문입니다 — 병원에 다녀와 약을 먹입니다.
///
/// **판정하지 않습니다.** 며칠 안에 몇 번이면 이상인지에 대한 기준이 어느
/// 출처에도 없습니다. 대신 같은 이유가 두 번 이상 나왔다는 사실만 셉니다.
class CareRecordPage extends StatefulWidget {
  const CareRecordPage({super.key});

  @override
  State<CareRecordPage> createState() => _CareRecordPageState();
}

enum _Tab { medication, visit }

class _CareRecordPageState extends State<CareRecordPage> {
  _Tab _tab = _Tab.medication;

  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _noteController = TextEditingController();

  /// 기록은 대개 약을 먹인 직후·병원에 다녀온 뒤에 남깁니다.
  final _time = RecordTimeController.now();

  MedicationReason _medicationReason = MedicationReason.fever;
  VisitReason _visitReason = VisitReason.fever;

  Baby? _baby;
  List<MedicationRecord> _medications = [];
  List<HospitalVisit> _visits = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _hospitalController.dispose();
    _noteController.dispose();
    _time.dispose();
    super.dispose();
  }

  /// 반복 창(90일) 안의 기록을 넉넉히 담을 상한. 이 기간에 이만큼 적는
  /// 경우는 없다고 봅니다.
  static const int _windowLimit = 300;

  /// 아래 이력 목록에 보여줄 건수. 창 전체를 그대로 늘어놓으면 화면이
  /// 끝없이 길어집니다.
  static const int _historyLimit = 20;

  /// 이력 목록에 보여줄 기록. **창을 걸지 않고 읽습니다.**
  ///
  /// 반복 집계용 [_medications]/[_visits]와 나눠 둡니다. 그쪽은 90일 창을
  /// 걸어 읽으므로, 그것을 이력에도 쓰면 90일이 넘은 기록만 있는 사람에게
  /// "아직 기록이 없습니다"가 뜹니다.
  List<MedicationRecord> _medicationHistory = [];
  List<HospitalVisit> _visitHistory = [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final baby = await BabyService.loadCurrent();

      // 반복 집계가 세는 창 전체를 읽습니다. 기본 20건에만 기대면 "지난
      // 90일 동안 ○○로 N번"이라 적어 두고 실제로는 최신 20건만 세게 됩니다
      // — 3주 전 구토 3건이 목록에서 통째로 사라집니다.
      final since = DateTime.now()
          .subtract(const Duration(days: CareRecordService.repeatWindowDays));

      // **이력 목록은 창을 걸지 않고 따로 읽습니다.**
      //
      // 예전에는 이 창의 결과를 이력에도 그대로 썼습니다. 그래서 90일이
      // 넘은 기록만 있는 사람에게 "아직 투약 기록이 없습니다"가 떴습니다 —
      // 기록은 멀쩡히 있는데요. 창은 반복 집계가 쓰는 것이지 이력이
      // 쓰는 것이 아닙니다.
      final results = baby == null
          ? null
          : await Future.wait([
              CareRecordService.loadMedications(baby.id,
                  since: since, limit: _windowLimit),
              CareRecordService.loadVisits(baby.id,
                  since: since, limit: _windowLimit),
              CareRecordService.loadMedications(baby.id, limit: _historyLimit),
              CareRecordService.loadVisits(baby.id, limit: _historyLimit),
            ]);

      if (!mounted) return;
      setState(() {
        _baby = baby;
        _medications =
            results == null ? [] : results[0] as List<MedicationRecord>;
        _visits = results == null ? [] : results[1] as List<HospitalVisit>;
        _medicationHistory =
            results == null ? [] : results[2] as List<MedicationRecord>;
        _visitHistory = results == null ? [] : results[3] as List<HospitalVisit>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '기록을 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final at = _time.toDateTime();
    if (at == null) {
      _showMessage('시간을 다시 골라 주세요.');
      return;
    }

    // 어느 탭에 저장할지 여기서 확정합니다. await 뒤에 _tab을 다시 읽으면,
    // 저장 중에 탭을 바꿨을 때 검증한 것과 다른 표에 들어갑니다.
    final tab = _tab;

    if (tab == _Tab.medication && _nameController.text.trim().isEmpty) {
      _showMessage('약 이름을 입력해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      // 화면을 열 때 잡은 아이에만 저장합니다. 저장 순간에 다시 고르면,
      // 화면을 열 때 조회가 실패했을 경우 다른 아이가 뽑힐 수 있습니다.
      final baby = _baby;
      if (baby == null) {
        // 조회가 실패한 것과 아이가 아직 없는 것을 구별합니다.
        // 뒤쪽이라면 화면을 다시 열어도 소용없고, 등록으로 보내야 합니다.
        notifyMissingBaby(context,
            state: _loading
                ? BabyLookup.loading
                : _error != null
                    ? BabyLookup.failed
                    : BabyLookup.none,
            onRegistered: _load);
        return;
      }

      if (tab == _Tab.medication) {
        await CareRecordService.saveMedication(
          babyId: baby.id,
          name: _nameController.text,
          dose: _doseController.text,
          reason: _medicationReason,
          takenAt: at,
        );
        _nameController.clear();
        _doseController.clear();
      } else {
        await CareRecordService.saveVisit(
          babyId: baby.id,
          hospitalName: _hospitalController.text,
          reason: _visitReason,
          note: _noteController.text,
          visitedAt: at,
        );
        _hospitalController.clear();
        _noteController.clear();
      }

      if (!mounted) return;
      _showMessage('기록했습니다.');
      await _load();
    } catch (e) {
      _showMessage('저장하지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      if (_tab == _Tab.medication) {
        await CareRecordService.deleteMedication(id);
      } else {
        await CareRecordService.deleteVisit(id);
      }
      await _load();
    } catch (e) {
      _showMessage('삭제하지 못했습니다. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repeats = repeatedReasons(medications: _medications, visits: _visits);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const CommonAppBar(
        title: '약 · 병원 기록',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabs(),
              const SizedBox(height: 28),
              if (_tab == _Tab.medication)
                ..._buildMedicationForm()
              else
                ..._buildVisitForm(),
              const SizedBox(height: 24),
              RecordTimeField(
                label: _tab == _Tab.medication ? '먹인 시간' : '방문 시간',
                controller: _time,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 28),
              RecordSaveButton(onPressed: _save, saving: _saving),
              if (repeats.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildRepeatCard(repeats),
              ],
              const SizedBox(height: 32),
              RecordHistorySection(
                title: _tab == _Tab.medication ? '최근 투약' : '최근 병원 방문',
                loading: _loading,
                error: _error,
                onRetry: _load,
                onDelete: _delete,
                emptyText: _tab == _Tab.medication
                    ? '아직 투약 기록이 없습니다.'
                    : '아직 병원 방문 기록이 없습니다.',
                entries: _tab == _Tab.medication
                    ? [
                        for (final m in _medicationHistory)
                          RecordHistoryEntry(
                            id: m.id,
                            title: formatRecordTime(m.takenAt),
                            subtitle: m.summary,
                          ),
                      ]
                    : [
                        for (final v in _visitHistory)
                          RecordHistoryEntry(
                            id: v.id,
                            title: formatRecordTime(v.visitedAt),
                            subtitle: v.summary,
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(child: _tabButton(_Tab.medication, '약 복용', Icons.medication_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _tabButton(_Tab.visit, '병원 방문', Icons.local_hospital_outlined)),
      ],
    );
  }

  Widget _tabButton(_Tab tab, String label, IconData icon) {
    final selected = _tab == tab;
    return GestureDetector(
      // 탭을 바꿔도 시간은 그대로 둡니다. 대개 같은 날 일을 이어서 적습니다.
      // 저장 중에는 잠급니다 — 아래 목록과 폼이 저장 중인 것과 어긋나 보입니다.
      onTap: _saving ? null : () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.primary : context.colors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.primary : context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMedicationForm() {
    return [
      _label('약 이름'),
      const SizedBox(height: 10),
      _textField(_nameController, hint: '예) 해열시럽', maxLength: 100),
      const SizedBox(height: 20),
      _label('용량'),
      const SizedBox(height: 10),
      // 단위가 'ml', '포', '알'로 제각각이라 숫자로 쪼개지 않습니다.
      _textField(_doseController, hint: '예) 5ml · 1포 (선택)', maxLength: 50),
      const SizedBox(height: 20),
      _label('먹인 이유'),
      const SizedBox(height: 10),
      _reasonChips(
        values: MedicationReason.values,
        labelOf: (r) => r.label,
        selected: _medicationReason,
        onSelect: (r) => setState(() => _medicationReason = r),
      ),
    ];
  }

  List<Widget> _buildVisitForm() {
    return [
      _label('병원'),
      const SizedBox(height: 10),
      _textField(_hospitalController, hint: '예) 우리소아과 (선택)', maxLength: 100),
      const SizedBox(height: 20),
      _label('방문 이유'),
      const SizedBox(height: 10),
      _reasonChips(
        values: VisitReason.values,
        labelOf: (r) => r.label,
        selected: _visitReason,
        onSelect: (r) => setState(() => _visitReason = r),
      ),
      const SizedBox(height: 20),
      _label('진료 메모'),
      const SizedBox(height: 10),
      _textField(
        _noteController,
        hint: '들은 이야기를 적어 두세요 (선택)',
        maxLength: 500,
        maxLines: 3,
      ),
    ];
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        // 글자 수는 한계에 가까울 때만 의미가 있습니다. 늘 띄우면 시끄럽습니다.
        counterText: '',
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _reasonChips<T>({
    required List<T> values,
    required String Function(T) labelOf,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          GestureDetector(
            onTap: () => onSelect(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: value == selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: value == selected
                      ? AppColors.primary
                      : context.colors.border,
                  width: 1.2,
                ),
              ),
              child: Text(
                labelOf(value),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: value == selected
                      ? AppColors.primary
                      : context.colors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 같은 이유가 두 번 이상 나왔다는 사실만 보여줍니다.
  ///
  /// 몇 번이면 많은 것인지는 쓰지 않습니다. 그런 기준을 가진 출처가 없고,
  /// 지어내면 이 앱이 하지 않기로 한 판정이 됩니다.
  Widget _buildRepeatCard(List<ReasonCount> repeats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.primarySurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 ${CareRecordService.repeatWindowDays}일 동안 반복된 것',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final r in repeats)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${r.label} · ${r.count}번',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '기록한 횟수를 세어 보여드리는 것입니다. '
            '많고 적음을 판단하지 않으니, 걱정되면 진료 때 이 기록을 보여주세요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
