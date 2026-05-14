import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DiaperRecordPage extends StatefulWidget {
  const DiaperRecordPage({super.key});

  @override
  State<DiaperRecordPage> createState() => _DiaperRecordPageState();
}

class _DiaperRecordPageState extends State<DiaperRecordPage> {
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);

  String selectedDiaperType = "소변";
  String selectedStoolState = "황금변";
  String selectedAmPm = "AM";

  final TextEditingController hourController =
      TextEditingController(text: "08");

  final TextEditingController minuteController =
      TextEditingController(text: "40");

  void selectDiaper(String type) {
    setState(() => selectedDiaperType = type);
  }

  void selectStool(String state) {
    setState(() => selectedStoolState = state);
  }

  void selectAmPm(String value) {
    setState(() => selectedAmPm = value);
  }

  void handleAnalyze() {
    debugPrint(
        "배변 기록 분석: $selectedDiaperType / $selectedStoolState / $selectedAmPm ${hourController.text}:${minuteController.text}");
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
      body: SafeArea(
        child: Padding(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // AM / PM
                    _amPmButton("AM", "오전"),
                    const SizedBox(width: 8),
                    _amPmButton("PM", "오후"),

                    const SizedBox(width: 12),

                    // 시
                    SizedBox(
                      width: 50,
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

                          hourController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                                offset: hourController.text.length),
                          );
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ":",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),

                    // 분
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: minuteController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
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
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    "기록하고 분석하기",
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? primaryColor.withOpacity(0.1) : Colors.white,
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
          color: selected
              ? primaryColor.withOpacity(0.1)
              : Colors.white,
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
            color:
                selected ? primaryColor : secondaryTextColor,
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
          color: selected ? color.withOpacity(0.2) : Colors.white,
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