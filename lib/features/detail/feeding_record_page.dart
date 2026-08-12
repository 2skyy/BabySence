import 'package:flutter/material.dart';

import '../advice/ask_action.dart';
import 'assessment/assessment.dart';

import 'widgets/record_save_button.dart';

import '../../core/widgets/common_app_bar.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/baby_service.dart';
import 'feeding_record_service.dart';
import 'widgets/record_history.dart';
import 'widgets/record_time_field.dart';

class FeedingRecordPage extends StatefulWidget {
  const FeedingRecordPage({super.key});

  @override
  State<FeedingRecordPage> createState() => _FeedingRecordPageState();
}

class _FeedingRecordPageState extends State<FeedingRecordPage> {
  static const Color primaryColor = AppColors.primary;
  Color get backgroundColor => context.colors.background;
  Color get surfaceColor => context.colors.surface;
  Color get borderColor => context.colors.border;
  Color get textColor => context.colors.textPrimary;
  Color get secondaryTextColor => context.colors.textSecondary;

  final TextEditingController feedingAmountController = TextEditingController();

  String selectedFeedingType = '분유';

  /// 화면을 연 시각으로 시작합니다. 나중에 몰아서 적을 때는 직접 고칩니다.
  final _time = RecordTimeController.now();

  @override
  void dispose() {
    feedingAmountController.dispose();
    _time.dispose();
    super.dispose();
  }

  bool isSaving = false;

  Baby? _baby;
  List<FeedingRecord> _records = [];
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
          ? <FeedingRecord>[]
          : await FeedingRecordService.loadRecent(baby.id);

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
      await FeedingRecordService.delete(id);
      await _loadHistory();
    } catch (e) {
      _showMessage('삭제하지 못했습니다. $e');
    }
  }

  void handleFeedingTypeTap(String feedingType) {
    setState(() {
      selectedFeedingType = feedingType;
    });
  }

  Future<void> handleAnalyzeButtonTap() async {
    final type = FeedingType.fromLabel(selectedFeedingType);
    final amount = int.tryParse(feedingAmountController.text);

    // 모유(직수)는 계량이 불가능해 수유량을 받지 않습니다(테이블도 NULL 허용).
    if (type.allowsAmount) {
      if (amount == null) {
        _showMessage('수유량을 입력해주세요.');
        return;
      }
      // amount_ml의 CHECK 제약(0~2000)과 같은 범위입니다.
      if (amount < 0 || amount > 2000) {
        _showMessage('수유량은 0~2000ml 사이로 입력해주세요.');
        return;
      }
    }

    final fedAt = _time.toDateTime();
    if (fedAt == null) {
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

      await FeedingRecordService.save(
        babyId: baby.id,
        type: type,
        fedAt: fedAt,
        amountMl: amount,
      );

      if (!mounted) return;
      feedingAmountController.clear();
      _showMessage('수유 기록을 저장했습니다.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CommonAppBar(
        title: '수유 기록',
        actions: [AskAction(domain: AssessmentDomain.feeding)],
      ),
      body: SafeArea(
        // ★ 수정: 키보드가 켜져도 화면이 터지지 않고 부드럽게 스크롤되도록 설정
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '수유 방식과 수유량을\n기록해주세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '기록된 데이터는 AI 분석에 활용됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                '수유 형태',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildFeedingTypeButton('분유')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFeedingTypeButton('모유(직수)')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFeedingTypeButton('이유식')),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                '수유량 (ml)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: feedingAmountController,
                  // 모유(직수)는 계량이 불가능해 입력을 막습니다.
                  enabled: FeedingType.fromLabel(selectedFeedingType).allowsAmount,
                  keyboardType: TextInputType.number,
                  // ✅ 숫자만 입력 가능
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    hintText: '120',
                    hintStyle: TextStyle(
                      color: Color(0xFFB8BEC8),
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 28),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              RecordTimeField(
                label: '수유 시간',
                controller: _time,
                onChanged: () => setState(() {}),
              ),
              // ★ 수정: 스크롤뷰 내부에선 무한 확장을 시도하는 Spacer() 대신 고정 공백(SizedBox)을 줍니다.
              const SizedBox(height: 40),
              RecordSaveButton(
                onPressed: handleAnalyzeButtonTap,
                saving: isSaving,
              ),
              const SizedBox(height: 36),
              RecordHistorySection(
                title: '최근 수유 기록',
                loading: _loadingHistory,
                error: _historyError,
                onRetry: _loadHistory,
                onDelete: _deleteRecord,
                entries: [
                  for (final r in _records)
                    RecordHistoryEntry(
                      id: r.id,
                      title: formatRecordTime(r.fedAt),
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

  Widget _buildFeedingTypeButton(String feedingType) {
    final bool isSelected = selectedFeedingType == feedingType;

    return GestureDetector(
      onTap: () => handleFeedingTypeTap(feedingType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: 1.4,
          ),
        ),
        child: Text(
          feedingType,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? primaryColor
                : secondaryTextColor,
          ),
        ),
      ),
    );
  }
}