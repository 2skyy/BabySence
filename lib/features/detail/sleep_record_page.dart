import 'package:flutter/material.dart';

import 'widgets/record_save_button.dart';

import '../../core/widgets/common_app_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/sleep_type.dart';
import 'sleep_record_service.dart';
import 'widgets/now_time_button.dart';
import 'widgets/time_picker_box.dart';
import 'widgets/record_history.dart';

class SleepRecordPage extends StatefulWidget {
  const SleepRecordPage({super.key});

  @override
  State<SleepRecordPage> createState() => _SleepRecordPageState();
}

class _SleepRecordPageState extends State<SleepRecordPage> {
  static const Color primaryColor = AppColors.primary;
  Color get backgroundColor => context.colors.background;
  Color get borderColor => context.colors.border;
  Color get textColor => context.colors.textPrimary;
  Color get secondaryTextColor => context.colors.textSecondary;

  SleepType selectedSleepType = SleepType.night;

  /// 밤잠의 흔한 구간을 기본값으로 둡니다. 화면을 열 때 둘 다 지금으로
  /// 채우면 길이 0인 기록이 되므로 그렇게 하지 않습니다.
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 6, minute: 30);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Baby? _baby;
  List<SleepRecord> _records = [];
  bool _loadingHistory = true;
  String? _historyError;

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final baby = await BabyService.loadCurrent();
      final records = baby == null
          ? <SleepRecord>[]
          : await SleepRecordService.loadRecent(baby.id);

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
      await SleepRecordService.delete(id);
      await _loadHistory();
    } catch (e) {
      _showMessage('삭제하지 못했습니다. $e');
    }
  }

  bool isSaving = false;

  /// 취침 또는 기상 칸을 지금 시각으로 채웁니다.
  ///
  /// 수면은 시작과 끝이 몇 시간 떨어져 있어, 배변처럼 화면을 열 때 둘 다
  /// 지금으로 채우면 길이 0인 기록이 됩니다. 그래서 기본값은 그대로 두고
  /// 재우는 순간·깨는 순간에 각각 누르도록 했습니다.
  void _setNow({required bool isStart}) {
    final now = TimeOfDay.now();
    setState(() {
      if (isStart) {
        _startTime = now;
      } else {
        _endTime = now;
      }
    });
  }

  /// 고른 시각을 실제 날짜가 붙은 시각으로 만듭니다.
  ///
  /// 취침이 미래로 계산되면 어제로 봅니다(아침에 전날 밤잠을 기록하는 경우).
  /// 기상이 취침보다 이르면 서비스가 하루를 더합니다(자정을 넘긴 밤잠).
  ///
  /// 시간 선택기가 유효한 값만 주므로 실패할 수 없습니다. 예전에는 직접
  /// 타이핑한 숫자를 파싱해야 해서 '13시' 같은 값을 걸러내야 했습니다.
  ({DateTime start, DateTime end}) _sleepPeriod() {
    final now = DateTime.now();
    var start = DateTime(
        now.year, now.month, now.day, _startTime.hour, _startTime.minute);
    if (start.isAfter(now)) start = start.subtract(const Duration(days: 1));

    final end = DateTime(
        start.year, start.month, start.day, _endTime.hour, _endTime.minute);

    return (start: start, end: end);
  }

  Future<void> handleAnalyze() async {
    final period = _sleepPeriod();

    setState(() => isSaving = true);
    try {
      // 이력을 불러올 때 이미 조회했으므로 재사용합니다.
      final baby = _baby ?? await BabyService.loadCurrent();
      if (baby == null) {
        _showMessage('먼저 아이 정보를 등록해주세요.');
        return;
      }

      await SleepRecordService.save(
        babyId: baby.id,
        type: selectedSleepType,
        startedAt: period.start,
        endedAt: period.end,
      );

      if (!mounted) return;
      _showMessage('수면 기록을 저장했습니다.');
      // 화면을 닫지 않고 아래 이력에 바로 보여줍니다.
      await _loadHistory();
    } catch (e) {
      _showMessage('저장하지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void handleSleepTypeTap(SleepType type) {
    setState(() {
      selectedSleepType = type;
    });
  }

  String getTotalSleepTime() {
    final start =
        Duration(hours: _startTime.hour, minutes: _startTime.minute);
    var end = Duration(hours: _endTime.hour, minutes: _endTime.minute);

    // 기상이 취침보다 이르면 자정을 넘긴 것입니다.
    if (end < start) end += const Duration(days: 1);

    final diff = end - start;
    return '${diff.inHours}시간 ${diff.inMinutes % 60}분';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CommonAppBar(title: '수면 기록'),
      // ★ 수정: 바닥 터짐 방지를 위해 스크롤 뷰로 교체
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '수면 종류',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _sleepTypeButton(SleepType.night)),
                  const SizedBox(width: 12),
                  Expanded(child: _sleepTypeButton(SleepType.nap)),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _timeHeader('시작 시간', isStart: true)),
                  Expanded(child: _timeHeader('종료 시간', isStart: false)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeBox(isStart: true)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6), // 간격 소폭 축소
                    child: Text(
                      '~',
                      style: TextStyle(fontSize: 20, color: secondaryTextColor),
                    ),
                  ),
                  Expanded(child: _timeBox(isStart: false)),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 글자 크기를 키운 기기에서 라벨과 값이 한 줄을 넘겼습니다.
                    // 라벨이 먼저 줄어들도록 두고 값은 그대로 보여줍니다.
                    Flexible(
                      child: Text(
                        '총 수면 시간',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      getTotalSleepTime(),
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              // ★ 수정: Spacer() 제거 후 적절한 아래 공백 확보
              const SizedBox(height: 40),
              RecordSaveButton(
                onPressed: handleAnalyze,
                saving: isSaving,
              ),
              const SizedBox(height: 36),
              RecordHistorySection(
                title: '최근 수면 기록',
                loading: _loadingHistory,
                error: _historyError,
                onRetry: _loadHistory,
                onDelete: _deleteRecord,
                entries: [
                  for (final r in _records)
                    RecordHistoryEntry(
                      id: r.id,
                      title: formatRecordTime(r.startedAt),
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

  /// 라벨과 '지금' 버튼을 한 줄에 둡니다.
  ///
  /// 폭이 절반뿐이라 글자를 키우면 라벨이 먼저 줄어들도록 [Flexible]로 감쌉니다.
  Widget _timeHeader(String label, {required bool isStart}) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        NowTimeButton(
          onPressed: () => _setNow(isStart: isStart),
          semanticLabel: isStart ? '시작 시간' : '종료 시간',
        ),
      ],
    );
  }

  Widget _sleepTypeButton(SleepType type) {
    final selected = selectedSleepType == type;
    return GestureDetector(
      onTap: () => handleSleepTypeTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
            width: 1.4,
          ),
        ),
        child: Text(
          type.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? primaryColor : secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _timeBox({required bool isStart}) {
    return TimePickerBox(
      value: isStart ? _startTime : _endTime,
      helpText: isStart ? '시작 시간' : '종료 시간',
      onChanged: (picked) => setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      }),
    );
  }
}