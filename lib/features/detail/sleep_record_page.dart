import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SleepRecordPage extends StatefulWidget {
  const SleepRecordPage({super.key});

  @override
  State<SleepRecordPage> createState() => _SleepRecordPageState();
}

class _SleepRecordPageState extends State<SleepRecordPage> {
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);
  
  String selectedSleepType = '밤잠';

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

  void handleAnalyze() {
    debugPrint('수면 기록 분석');
  }

  void handleSleepTypeTap(String type) {
    setState(() {
      selectedSleepType = type;
    });
  }

  int _convertTo24Hour(
    String period,
    int hour,
  ) {
    if (period == '오전') {
      if (hour == 12) return 0;
      return hour;
    }

    if (hour == 12) return 12;

    return hour + 12;
  }

  String getTotalSleepTime() {
    try {
      int startHour =
          int.tryParse(startHourController.text) ?? 0;
      int startMinute =
          int.tryParse(startMinuteController.text) ?? 0;

      int endHour =
          int.tryParse(endHourController.text) ?? 0;
      int endMinute =
          int.tryParse(endMinuteController.text) ?? 0;

      startHour =
          _convertTo24Hour(startPeriod, startHour);

      endHour =
          _convertTo24Hour(endPeriod, endHour);

      final start =
          Duration(hours: startHour, minutes: startMinute);

      var end =
          Duration(hours: endHour, minutes: endMinute);

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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: textColor,
          ),
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

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
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
                  Expanded(
                    child: _sleepTypeButton('밤잠'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sleepTypeButton('낮잠'),
                  ),
                ],
              ),

            const SizedBox(height: 28),

Row(
  children: const [
    Expanded(
      child: Text(
        '시작 시간',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    Expanded(
      child: Text(
        '종료 시간',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ],
),

const SizedBox(height: 12),

Row(
  children: [
    Expanded(
      child: _timeBox(
        isStart: true,
      ),
    ),

    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '~',
        style: TextStyle(
          fontSize: 20,
          color: secondaryTextColor,
        ),
      ),
    ),

    Expanded(
      child: _timeBox(
        isStart: false,
      ),
    ),
  ],
),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
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

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: handleAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '기록하고 분석하기',
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

  Widget _sleepTypeButton(String type) {
    final selected = selectedSleepType == type;

    return GestureDetector(
      onTap: () => handleSleepTypeTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? primaryColor : borderColor,
            width: 1.4,
          ),
        ),
        child: Text(
          type,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected
                ? primaryColor
                : secondaryTextColor,
          ),
        ),
      ),
    );
  }
Widget _timeBox({
  required bool isStart,
}) {
  final hourController =
      isStart ? startHourController : endHourController;

  final minuteController =
      isStart ? startMinuteController : endMinuteController;

  final selectedPeriod =
      isStart ? startPeriod : endPeriod;

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<String>(
          value: selectedPeriod,
          underline: const SizedBox(),
          isDense: true,
          items: const [
            DropdownMenuItem(
              value: '오전',
              child: Text('오전'),
            ),
            DropdownMenuItem(
              value: '오후',
              child: Text('오후'),
            ),
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

        const SizedBox(width: 4),

        SizedBox(
          width: 24,
          child: TextField(
            controller: hourController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 2,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const Text(
          ':',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(
          width: 24,
          child: TextField(
            controller: minuteController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 2,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(width: 4),

        const Icon(
          Icons.access_time,
          size: 16,
          color: Colors.grey,
        ),
      ],
    ),
  );
}

       

}