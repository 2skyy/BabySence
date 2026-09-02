import 'package:flutter/material.dart';

import '../../core/widgets/missing_baby.dart';


import 'widgets/record_save_button.dart';

import '../../core/widgets/common_app_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'diaper_record_service.dart';
import 'widgets/record_history.dart';
import 'widgets/record_time_field.dart';

class DiaperRecordPage extends StatefulWidget {
  const DiaperRecordPage({super.key});

  @override
  State<DiaperRecordPage> createState() => _DiaperRecordPageState();
}

class _DiaperRecordPageState extends State<DiaperRecordPage> {
  static const Color primaryColor = AppColors.primary;
  Color get backgroundColor => context.colors.background;
  Color get borderColor => context.colors.border;
  Color get textColor => context.colors.textPrimary;
  Color get secondaryTextColor => context.colors.textSecondary;

  String selectedDiaperType = DiaperType.urine.label;
  String selectedStoolState = StoolState.golden.label;

  /// 기록은 대개 기저귀를 간 직후에 남깁니다. 화면을 열면 지금 시각이 들어가
  /// 있어 대부분의 경우 시간을 건드릴 필요가 없습니다.
  final _time = RecordTimeController.now();

  /// 대변이 섞여 있는 종류인가. 소변에는 대변 상태가 없습니다.
  bool get _hasStool => selectedDiaperType != DiaperType.urine.label;

  void selectDiaper(String type) {
    setState(() => selectedDiaperType = type);
  }

  void selectStool(String state) {
    setState(() => selectedStoolState = state);
  }

  bool isSaving = false;

  Baby? _baby;
  List<DiaperRecord> _records = [];
  bool _loadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final baby = await BabyService.loadCurrent();
      final records = baby == null
          ? <DiaperRecord>[]
          : await DiaperRecordService.loadRecent(baby.id);

      if (!mounted) return;
      setState(() {
        _baby = baby;
        _records = records;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = '기록을 불러오지 못했습니다.\n$e';
        _loadingHistory = false;
      });
    }
  }

  Future<void> _deleteRecord(String id) async {
    try {
      await DiaperRecordService.delete(id);
      await _loadHistory();
    } catch (e) {
      _showMessage("삭제하지 못했습니다. $e");
    }
  }

  Future<void> handleAnalyze() async {
    final recordedAt = _time.toDateTime();
    if (recordedAt == null) {
      _showMessage("시간을 1~12시, 0~59분으로 입력해주세요.");
      return;
    }

    final type = DiaperType.fromLabel(selectedDiaperType);

    setState(() => isSaving = true);
    try {
      // 화면을 열 때 잡은 아이에만 저장합니다. 저장 순간에 다시 고르면,
      // 화면을 열 때 조회가 실패했을 경우 다른 아이가 뽑힐 수 있습니다.
      final baby = _baby;
      if (baby == null) {
        // 조회가 실패한 것과 아이가 아직 없는 것을 구별합니다.
        // 뒤쪽이라면 화면을 다시 열어도 소용없고, 등록으로 보내야 합니다.
        notifyMissingBaby(context,
            state: _loadingHistory
                ? BabyLookup.loading
                : _historyError != null
                    ? BabyLookup.failed
                    : BabyLookup.none,
            onRegistered: _loadHistory);
        return;
      }

      await DiaperRecordService.save(
        babyId: baby.id,
        type: type,
        recordedAt: recordedAt,
        // 소변이면 서비스가 NULL로 넣습니다(CHECK 제약).
        stoolState: StoolState.fromLabel(selectedStoolState),
      );

      if (!mounted) return;
      _showMessage("배변 기록을 저장했습니다.");
      // 화면을 닫지 않고 아래 이력에 바로 보여줍니다.
      await _loadHistory();
    } catch (e) {
      _showMessage("저장하지 못했습니다. $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CommonAppBar(
        title: '배변 기록',
      ),
      // ★ 수정: 키보드가 올라올 때 화면이 부드럽게 스크롤되도록 전체를 감싸줍니다.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                "배변 종류",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _diaperButton(DiaperType.urine.label)),
                  const SizedBox(width: 10),
                  Expanded(child: _diaperButton(DiaperType.stool.label)),
                  const SizedBox(width: 10),
                  Expanded(child: _diaperButton(DiaperType.mixed.label)),
                ],
              ),
              // 소변에는 대변 상태가 없습니다. 서비스도 NULL로 넣습니다.
              // 고를 수 있게 두면 고른 값이 저장된다고 오해합니다.
              if (_hasStool) ...[
                const SizedBox(height: 28),
                Text(
                  "대변 상태",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stoolButton(StoolState.golden.label, Colors.amber),
                    _stoolButton(StoolState.green.label, Colors.green),
                    _stoolButton(StoolState.loose.label, Colors.blue),
                    _stoolButton(StoolState.hard.label, Colors.brown),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              RecordTimeField(
                label: '교체 시간',
                controller: _time,
                onChanged: () => setState(() {}),
              ),
              // ★ 수정: 스크롤 뷰 내부에서 에러를 내는 Spacer() 대신 고정 간격 지정
              const SizedBox(height: 40),
              RecordSaveButton(
                onPressed: handleAnalyze,
                saving: isSaving,
              ),
              const SizedBox(height: 36),
              RecordHistorySection(
                title: "최근 배변 기록",
                loading: _loadingHistory,
                error: _historyError,
                onRetry: _loadHistory,
                onDelete: _deleteRecord,
                entries: [
                  for (final r in _records)
                    RecordHistoryEntry(
                      id: r.id,
                      title: formatRecordTime(r.recordedAt),
                      subtitle: r.summary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diaperButton(String label) {
    final selected = selectedDiaperType == label;
    return GestureDetector(
      onTap: () => selectDiaper(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? primaryColor : secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _stoolButton(String label, Color color) {
    final selected = selectedStoolState == label;
    return GestureDetector(
      onTap: () => selectStool(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : borderColor,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? color : secondaryTextColor,
          ),
        ),
      ),
    );
  }
}