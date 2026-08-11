import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/sleep_type.dart';
import 'sleep_record_service.dart';
import 'widgets/now_time_button.dart';
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
  String startPeriod = '오후';
  String endPeriod = '오전';

  final startHourController = TextEditingController(text: '08');
  final startMinuteController = TextEditingController(text: '00');
  final endHourController = TextEditingController(text: '06');
  final endMinuteController = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    startHourController.addListener(() => setState(() {}));
    startMinuteController.addListener(() => setState(() {}));
    endHourController.addListener(() => setState(() {}));
    endMinuteController.addListener(() => setState(() {}));
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

  @override
  void dispose() {
    startHourController.dispose();
    startMinuteController.dispose();
    endHourController.dispose();
    endMinuteController.dispose();
    super.dispose();
  }

  bool isSaving = false;

  /// 취침 또는 기상 칸을 지금 시각으로 채웁니다.
  ///
  /// 수면은 시작과 끝이 몇 시간 떨어져 있어, 배변처럼 화면을 열 때 둘 다
  /// 지금으로 채우면 길이 0인 기록이 됩니다. 그래서 기본값은 그대로 두고
  /// 재우는 순간·깨는 순간에 각각 누르도록 했습니다.
  void _setNow({required bool isStart}) {
    final now = nowTimeFields();
    setState(() {
      if (isStart) {
        startPeriod = now.period;
        startHourController.text = now.hour;
        startMinuteController.text = now.minute;
      } else {
        endPeriod = now.period;
        endHourController.text = now.hour;
        endMinuteController.text = now.minute;
      }
    });
  }

  /// 화면의 오전/오후 + 시:분을 실제 시각으로 만듭니다.
  ///
  /// 취침이 미래로 계산되면 어제로 봅니다(아침에 전날 밤잠을 기록하는 경우).
  /// 기상이 취침보다 이르면 서비스가 하루를 더합니다(자정을 넘긴 밤잠).
  ({DateTime start, DateTime end})? _sleepPeriod() {
    final sh = int.tryParse(startHourController.text);
    final sm = int.tryParse(startMinuteController.text);
    final eh = int.tryParse(endHourController.text);
    final em = int.tryParse(endMinuteController.text);
    if (sh == null || sm == null || eh == null || em == null) return null;
    if (sh < 1 || sh > 12 || eh < 1 || eh > 12) return null;
    if (sm < 0 || sm > 59 || em < 0 || em > 59) return null;

    final now = DateTime.now();
    var start = DateTime(
      now.year, now.month, now.day, _convertTo24Hour(startPeriod, sh), sm);
    if (start.isAfter(now)) start = start.subtract(const Duration(days: 1));

    final end = DateTime(
      start.year, start.month, start.day, _convertTo24Hour(endPeriod, eh), em);

    return (start: start, end: end);
  }

  Future<void> handleAnalyze() async {
    final period = _sleepPeriod();
    if (period == null) {
      _showMessage('시간을 1~12시, 0~59분으로 입력해주세요.');
      return;
    }

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

  int _convertTo24Hour(String period, int hour) {
    if (period == '오전') {
      if (hour == 12) return 0;
      return hour;
    }
    if (hour == 12) return 12;
    return hour + 12;
  }

  String getTotalSleepTime() {
    try {
      int startHour = int.tryParse(startHourController.text) ?? 0;
      int startMinute = int.tryParse(startMinuteController.text) ?? 0;
      int endHour = int.tryParse(endHourController.text) ?? 0;
      int endMinute = int.tryParse(endMinuteController.text) ?? 0;

      startHour = _convertTo24Hour(startPeriod, startHour);
      endHour = _convertTo24Hour(endPeriod, endHour);

      final start = Duration(hours: startHour, minutes: startMinute);
      var end = Duration(hours: endHour, minutes: endMinute);

      if (end < start) {
        end += const Duration(days: 1);
      }

      final diff = end - start;
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      return '$hours시간 $minutes분';
    } catch (_) {
      return '0시간 0분';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '수면 기록',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: isSaving ? null : handleAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                    '기록하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
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
    final hourController = isStart ? startHourController : endHourController;
    final minuteController = isStart ? startMinuteController : endMinuteController;
    final selectedPeriod = isStart ? startPeriod : endPeriod;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      // 한 줄에 오전/오후 + 시:분을 모두 넣으면 좁은 기기나 글자 확대 설정에서
      // 넘칩니다(320px에서 23px, 1.3배에서 12px 초과). 두 줄로 나눕니다.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 오전/오후는 두 값뿐이라 드롭다운 대신 눌러서 바꾸는 칩으로 둡니다.
          // 화살표 아이콘이 차지하던 폭도 함께 사라집니다.
          _periodToggle(isStart: isStart, selected: selectedPeriod),
          const SizedBox(height: 6),
          Row(
            children: [
              // 남은 폭을 반씩 나눠 갖게 해서 어떤 글자 배율에서도 넘치지 않게 합니다.
              Expanded(child: _timeField(hourController)),
              const Text(':',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Expanded(child: _timeField(minuteController)),
            ],
          ),
        ],
      ),
    );
  }

  /// 오전/오후 전환. 값이 둘뿐이라 누를 때마다 뒤집습니다.
  Widget _periodToggle({required bool isStart, required String selected}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          final next = selected == '오전' ? '오후' : '오전';
          if (isStart) {
            startPeriod = next;
          } else {
            endPeriod = next;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.swap_horiz, size: 14, color: primaryColor),
          ],
        ),
      ),
    );
  }

  /// 시 또는 분 입력칸.
  ///
  /// 폭을 고정하지 않습니다. TextField는 고유 폭이 크게 잡혀서 IntrinsicWidth로
  /// 감싸면 칸이 부풀어 좁은 기기에서 넘칩니다. 부모 Row가 Expanded로 폭을
  /// 나눠주는 것을 그대로 받습니다.
  Widget _timeField(TextEditingController controller) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      maxLength: 2,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        counterText: '',
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
    );
  }
}