import 'package:flutter/material.dart';

import '../../core/widgets/missing_baby.dart';

import 'widgets/record_save_button.dart';

import '../../core/widgets/common_app_bar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../advice/ask_action.dart';
import 'assessment/assessment.dart';
import 'assessment/assessment_service.dart';
import 'assessment/temperature_rules.dart';
import 'temperature_record_service.dart';
import 'widgets/record_history.dart';
import 'widgets/record_time_field.dart';
import 'widgets/temperature_picker.dart';

class TemperatureRecordPage extends StatefulWidget {
  const TemperatureRecordPage({super.key});

  @override
  State<TemperatureRecordPage> createState() => _TemperatureRecordPageState();
}

class _TemperatureRecordPageState extends State<TemperatureRecordPage> {
  Color get backgroundColor => context.colors.background;
  Color get textColor => context.colors.textPrimary;
  static const double defaultTemperature = 36.5;

  final TextEditingController temperatureController = TextEditingController();

  final List<String> selectedSymptoms = [];
  late double selectedTemperature;

  /// 화면을 연 시각으로 시작합니다. 나중에 몰아서 적을 때는 직접 고칩니다.
  final _time = RecordTimeController.now();

  final List<String> symptoms = ['없음', '기침', '콧물', '발진', '구토', '설사'];

  @override
  void initState() {
    super.initState();
    selectedTemperature = defaultTemperature;
    temperatureController.text = selectedTemperature.toStringAsFixed(1);
    _loadHistory();
  }

  Baby? _baby;
  List<TemperatureRecord> _records = [];
  bool _loadingHistory = true;
  String? _historyError;

  /// 방금 저장한 기록의 판정. 저장 전에는 null이라 카드를 숨깁니다.
  Assessment? _lastAssessment;

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final baby = await BabyService.loadCurrent();
      final records = baby == null
          ? <TemperatureRecord>[]
          : await TemperatureRecordService.loadRecent(baby.id);

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
      await TemperatureRecordService.delete(id);
      await _loadHistory();
    } catch (e) {
      _showMessage('삭제하지 못했습니다. $e');
    }
  }

  @override
  void dispose() {
    temperatureController.dispose();
    _time.dispose();
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

    // 판정 기준을 개월 수로 고르므로, 잰 시각이 곧 판정 근거이기도 합니다.
    final measuredAt = _time.toDateTime();
    if (measuredAt == null) {
      _showMessage('시간을 1~12시, 0~59분으로 입력해주세요.');
      return;
    }

    setState(() => isSaving = true);
    try {
      // 화면을 열 때 잡은 아이에만 저장합니다.
      //
      // 예전에는 `_baby ?? await loadCurrent()`로 저장 순간에 아이를 다시
      // 골랐습니다. 화면을 열 때 조회가 실패했다면, 그 사이 함께 보기가
      // 끊기거나 해서 **다른 아이가 뽑힐 수 있습니다.** 보고 있던 아이가
      // 아닌 곳에 체온이 저장되고, 사용자에게는 아무 표시도 없습니다.
      final baby = _baby;
      if (baby == null) {
        // 조회가 실패한 것과 아이가 아직 없는 것을 구별합니다.
        // 뒤쪽이라면 화면을 다시 열어도 소용없고, 등록으로 보내야 합니다.
        notifyMissingBaby(context,
            loadFailed: _historyError != null, onRegistered: _loadHistory);
        return;
      }

      final symptomsSaved = await TemperatureRecordService.save(
        babyId: baby.id,
        temperatureC: value,
        measuredAt: measuredAt,
        symptoms: symptoms,
      );

      // 체온은 들어갔습니다. 통째로 실패했다고 말하면 다시 눌러 중복이 됩니다.
      if (!symptomsSaved) {
        _showMessage('체온은 저장했지만 동반 증상은 저장하지 못했습니다.');
      }

      // 연령대별 기준으로 판정하고 결과를 남깁니다.
      // 판정은 앱에서 계산하므로 저장이 실패해도 안내는 보여줄 수 있습니다.
      final assessment = TemperatureRules.assess(
        temperatureC: value,
        ageInMonths: ageInMonthsAt(baby.birthDate, measuredAt),
        // 6개월 이상은 판정에 동반 증상을 함께 표시합니다(NICE NG143).
        symptoms: symptoms,
      );

      try {
        await AssessmentService.save(babyId: baby.id, assessment: assessment);
      } catch (e) {
        // 판정 저장 실패가 체온 기록 자체를 무효로 만들지는 않습니다.
        debugPrint('판정 저장 실패: $e');
      }

      if (!mounted) return;
      setState(() => _lastAssessment = assessment);
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

  Widget _buildAssessmentCard(Assessment assessment) {
    final color = TemperaturePicker.colorFor(assessment.level);
    final icon = switch (assessment.level) {
      AssessmentLevel.normal => Icons.check_circle,
      AssessmentLevel.caution => Icons.warning_amber_rounded,
      AssessmentLevel.consult => Icons.local_hospital,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                assessment.level.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 6개월 이상은 동반 증상 안내가 빈 줄 뒤에 붙습니다. 한 덩어리로
          // 두면 묻히므로 선을 그어 나눠 보여줍니다.
          for (final (i, paragraph)
              in assessment.guideText.split('\n\n').indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: color.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
            ],
            Text(
              paragraph,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );
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

  // --- 체온 선택 ---

  /// 0.1℃ 단위로 맞추고 화면 상태와 입력 컨트롤러를 함께 갱신합니다.
  void _setTemperature(double value) {
    setState(() {
      selectedTemperature = TemperaturePicker.snap(value);
      temperatureController.text = selectedTemperature.toStringAsFixed(1);
    });
  }

  /// 아이 나이(개월). 아직 아이 정보를 못 읽었으면 null입니다.
  int? get _ageInMonths {
    final baby = _baby;
    if (baby == null) return null;
    return ageInMonthsAt(baby.birthDate, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: CommonAppBar(
        title: '체온 기록',
        actions: [
          AskAction(
            domain: AssessmentDomain.temperature,
            assessment: _lastAssessment,
          ),
        ],
      ),

      // 이력 목록이 아래에 붙어 화면을 넘기므로 스크롤 뷰로 감쌉니다.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Center(
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

              TemperaturePicker(
                value: selectedTemperature,
                ageInMonths: _ageInMonths,
                onChanged: _setTemperature,
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

              const SizedBox(height: 32),

              RecordTimeField(
                label: '측정 시간',
                controller: _time,
                onChanged: () => setState(() {}),
              ),

              // 스크롤 뷰 안에서는 무한 확장을 시도하는 Spacer()를 쓸 수 없습니다.
              const SizedBox(height: 32),

              RecordSaveButton(
                onPressed: handleAnalyzeButtonTap,
                saving: isSaving,
              ),
              if (_lastAssessment != null) ...[
                const SizedBox(height: 24),
                _buildAssessmentCard(_lastAssessment!),
                const SizedBox(height: 12),
                // 판정을 보여주는 자리에는 반드시 함께 둡니다.
                const MedicalDisclaimer(),
              ],
              const SizedBox(height: 36),
              RecordHistorySection(
                title: '최근 체온 기록',
                loading: _loadingHistory,
                error: _historyError,
                onRetry: _loadHistory,
                onDelete: _deleteRecord,
                entries: [
                  for (final r in _records)
                    RecordHistoryEntry(
                      id: r.id,
                      title: formatRecordTime(r.measuredAt),
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

  // 🔥 칩 UI (적당히 크고 예쁘게)
  Widget _buildSymptomButton(String symptom) {
    final bool isSelected = selectedSymptoms.contains(symptom);

    return GestureDetector(
      onTap: () => handleSymptomTap(symptom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.error.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.error : context.colors.border,
            width: 1.2,
          ),
        ),
        child: Text(
          symptom,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.error : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
