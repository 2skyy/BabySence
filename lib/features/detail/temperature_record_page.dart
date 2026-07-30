import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'temperature_record_service.dart';

class TemperatureRecordPage extends StatefulWidget {
  const TemperatureRecordPage({super.key});

  @override
  State<TemperatureRecordPage> createState() => _TemperatureRecordPageState();
}

class _TemperatureRecordPageState extends State<TemperatureRecordPage> {
  static const Color buttonBlue = Color(0xFF2F80ED);
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color textColor = Color(0xFF1F2937);
  static const double defaultTemperature = 36.5;

  final TextEditingController temperatureController = TextEditingController();
  late final FixedExtentScrollController temperatureScrollController;

  final List<String> selectedSymptoms = [];
  late final List<double> temperatures;
  late double selectedTemperature;

  final List<String> symptoms = ['없음', '기침', '콧물', '발진', '구토', '설사'];

  @override
  void initState() {
    super.initState();
    temperatures = List.generate(151, (index) => (300 + index) / 10);
    selectedTemperature = defaultTemperature;

    final initialIndex = temperatures.indexWhere(
      (temperature) =>
          temperature.toStringAsFixed(1) ==
          defaultTemperature.toStringAsFixed(1),
    );
    temperatureScrollController = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 0,
    );
    temperatureController.text = selectedTemperature.toStringAsFixed(1);
  }

  @override
  void dispose() {
    temperatureScrollController.dispose();
    temperatureController.dispose();
    super.dispose();
  }

  bool isSaving = false;

  Future<void> handleAnalyzeButtonTap() async {
    final value = double.tryParse(temperatureController.text);

    if (value == null) {
      _showMessage('체온을 입력해주세요.');
      return;
    }

    // temperature_c의 CHECK 제약(30.0~45.0)과 같은 범위입니다.
    if (value < 30 || value > 45) {
      _showMessage('체온은 30~45도 사이로 입력해주세요.');
      return;
    }

    // UI의 '없음'은 저장하지 않습니다. 행이 하나도 없는 상태가 곧 '없음'입니다.
    final symptoms = selectedSymptoms
        .map(Symptom.fromLabel)
        .whereType<Symptom>()
        .toList();

    setState(() => isSaving = true);
    try {
      final baby = await BabyService.loadCurrent();
      if (baby == null) {
        _showMessage('먼저 아이 정보를 등록해주세요.');
        return;
      }

      await TemperatureRecordService.save(
        babyId: baby.id,
        temperatureC: value,
        measuredAt: DateTime.now(),
        symptoms: symptoms,
      );

      if (!mounted) return;
      _showMessage('체온 기록을 저장했습니다.');
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

  void handleSymptomTap(String symptom) {
    setState(() {
      if (symptom == '없음') {
        selectedSymptoms.clear();
        selectedSymptoms.add('없음');
        return;
      }

      selectedSymptoms.remove('없음');

      if (selectedSymptoms.contains(symptom)) {
        selectedSymptoms.remove(symptom);
      } else {
        selectedSymptoms.add(symptom);
      }
    });
  }

  void handleTemperatureChanged(int index) {
    setState(() {
      selectedTemperature = temperatures[index];
      temperatureController.text = selectedTemperature.toStringAsFixed(1);
    });
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
          '체온 기록',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Center(
                child: Text(
                  '현재 체온',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🔥 체온 입력 (빨간색 복구 완료)
              const SizedBox(height: 8),

              SizedBox(
                height: 170,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 44,
                  diameterRatio: 1.4,
                  perspective: 0.003,
                  physics: const FixedExtentScrollPhysics(),
                  controller: temperatureScrollController,
                  onSelectedItemChanged: handleTemperatureChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: temperatures.length,
                    builder: (context, index) {
                      final temperature = temperatures[index];
                      final isSelected =
                          temperature.toStringAsFixed(1) ==
                          selectedTemperature.toStringAsFixed(1);

                      return Center(
                        child: Text(
                          '${temperature.toStringAsFixed(1)}℃',
                          style: TextStyle(
                            fontSize: isSelected ? 28 : 20,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 36),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '동반 증상',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: symptoms
                      .map((symptom) => _buildSymptomButton(symptom))
                      .toList(),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: isSaving ? null : handleAnalyzeButtonTap,
                  style: ButtonStyle(
                    backgroundColor: const WidgetStatePropertyAll(buttonBlue),
                    elevation: const WidgetStatePropertyAll(0),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
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

  // 🔥 칩 UI (적당히 크고 예쁘게)
  Widget _buildSymptomButton(String symptom) {
    final bool isSelected = selectedSymptoms.contains(symptom);

    return GestureDetector(
      onTap: () => handleSymptomTap(symptom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.error.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.error : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          symptom,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
