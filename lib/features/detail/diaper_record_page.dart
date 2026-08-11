import 'package:flutter/material.dart';
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
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);

  String selectedDiaperType = "소변";
  String selectedStoolState = "황금변";

  /// 기록은 대개 기저귀를 간 직후에 남깁니다. 화면을 열면 지금 시각이 들어가
  /// 있어 대부분의 경우 시간을 건드릴 필요가 없습니다.
  final _time = RecordTimeController.now();

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
      // 이력을 불러올 때 이미 조회했으므로 재사용합니다.
      final baby = _baby ?? await BabyService.loadCurrent();
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
              RecordTimeField(
                label: '교체 시간',
                controller: _time,
                onChanged: () => setState(() {}),
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