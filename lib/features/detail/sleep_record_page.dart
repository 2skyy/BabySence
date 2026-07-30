import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import '../../core/services/noise_tracker.dart' show SleepType;
import 'sleep_record_service.dart';

class SleepRecordPage extends StatefulWidget {
  const SleepRecordPage({super.key});

  @override
  State<SleepRecordPage> createState() => _SleepRecordPageState();
}

class _SleepRecordPageState extends State<SleepRecordPage> {
  static const Color primaryColor = AppColors.primary;
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);

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
      final baby = await BabyService.loadCurrent();
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
      Navigator.pop(context);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
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
                children: const [
                  Expanded(
                    child: Text(
                      '시작 시간',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '종료 시간',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeBox(isStart: true)),
                  const Padding(
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
                    const Text(
                      '총 수면 시간',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
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
            ],
          ),
        ),
      ),
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
          color: selected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
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
      // ★ 수정: 내부 좌우 패딩을 12 -> 6으로 줄여 좁은 기기에서도 텍스트 밀림현상을 방어합니다.
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButton<String>(
            value: selectedPeriod,
            underline: const SizedBox(),
            isDense: true,
            items: const [
              DropdownMenuItem(value: '오전', child: Text('오전')),
              DropdownMenuItem(value: '오후', child: Text('오후')),
            ],
            onChanged: (value) {
              setState(() {
                if (isStart) {
                  startPeriod = value!;
                } else {
                  endPeriod = value!;
                }
              });
            },
          ),
          const SizedBox(width: 2), // ★ 수정: 간격 미세 조정
          SizedBox(
            width: 20, // ★ 수정: 가로폭 최적화
            child: TextField(
              controller: hourController,
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
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            width: 20, // ★ 수정: 가로폭 최적화
            child: TextField(
              controller: minuteController,
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
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.access_time, size: 14, color: Colors.grey), // ★ 크기 살짝 축소
        ],
      ),
    );
  }
}