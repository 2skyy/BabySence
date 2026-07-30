import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'diaper_record_service.dart';

class DiaperRecordPage extends StatefulWidget {
  const DiaperRecordPage({super.key});

  @override
  State<DiaperRecordPage> createState() => _DiaperRecordPageState();
}

class _DiaperRecordPageState extends State<DiaperRecordPage> {
  static const Color primaryColor = AppColors.primary;
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);

  String selectedDiaperType = "소변";
  String selectedStoolState = "황금변";
  String selectedAmPm = "AM";

  final TextEditingController hourController = TextEditingController(text: "08");
  final TextEditingController minuteController = TextEditingController(text: "40");

  void selectDiaper(String type) {
    setState(() => selectedDiaperType = type);
  }

  void selectStool(String state) {
    setState(() => selectedStoolState = state);
  }

  void selectAmPm(String value) {
    setState(() => selectedAmPm = value);
  }

  bool isSaving = false;

  /// 화면의 AM/PM + 시:분을 오늘 날짜의 시각으로 만듭니다.
  /// 미래 시각이 나오면 어제로 봅니다(자정 직후에 전날 기록을 넣는 경우).
  DateTime? _recordedAt() {
    final hour = int.tryParse(hourController.text);
    final minute = int.tryParse(minuteController.text);
    if (hour == null || minute == null) return null;
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;

    var hour24 = hour % 12;
    if (selectedAmPm == "PM") hour24 += 12;

    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, hour24, minute);
    return at.isAfter(now) ? at.subtract(const Duration(days: 1)) : at;
  }

  Future<void> handleAnalyze() async {
    final recordedAt = _recordedAt();
    if (recordedAt == null) {
      _showMessage("시간을 1~12시, 0~59분으로 입력해주세요.");
      return;
    }

    final type = DiaperType.fromLabel(selectedDiaperType);

    setState(() => isSaving = true);
    try {
      final baby = await BabyService.loadCurrent();
      if (baby == null) {
        _showMessage("먼저 아이 정보를 등록해주세요.");
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
      Navigator.pop(context);
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
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
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
          "배변 기록",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // ★ 수정: 키보드가 올라올 때 화면이 부드럽게 스크롤되도록 전체를 감싸줍니다.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
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
                  Expanded(child: _diaperButton("소변")),
                  const SizedBox(width: 10),
                  Expanded(child: _diaperButton("대변")),
                  const SizedBox(width: 10),
                  Expanded(child: _diaperButton("혼합")),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
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
                  _stoolButton("황금변", Colors.amber),
                  _stoolButton("녹변", Colors.green),
                  _stoolButton("묽음", Colors.blue),
                  _stoolButton("단단함", Colors.brown),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                "교체 시간",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _amPmButton("AM", "오전"),
                    const SizedBox(width: 6),
                    _amPmButton("PM", "오후"),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 45,
                      child: TextField(
                        controller: hourController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        onChanged: (value) {
                          if (value.isEmpty) return;
                          final intVal = int.tryParse(value);
                          if (intVal == null) return;
                          if (intVal < 1) {
                            hourController.text = "1";
                          } else if (intVal > 12) {
                            hourController.text = "12";
                          }
                          hourController.selection = TextSelection.fromPosition(
                            TextPosition(offset: hourController.text.length),
                          );
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ":",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 45,
                      child: TextField(
                        controller: minuteController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ★ 수정: 스크롤 뷰 내부에서 에러를 내는 Spacer() 대신 고정 간격 지정
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
                    "기록하기",
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

  Widget _amPmButton(String value, String label) {
    final selected = selectedAmPm == value;
    return GestureDetector(
      onTap: () => selectAmPm(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? primaryColor : secondaryTextColor,
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
          color: selected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
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
          color: selected ? color.withValues(alpha: 0.2) : Colors.white,
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