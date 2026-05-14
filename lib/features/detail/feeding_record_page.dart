// feeding_record_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FeedingRecordPage extends StatefulWidget {
  const FeedingRecordPage({super.key});

  @override
  State<FeedingRecordPage> createState() => _FeedingRecordPageState();
}

class _FeedingRecordPageState extends State<FeedingRecordPage> {
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);

  final TextEditingController feedingAmountController =
      TextEditingController();

  String selectedFeedingType = '분유';

  @override
  void dispose() {
    feedingAmountController.dispose();
    super.dispose();
  }

  void handleFeedingTypeTap(String feedingType) {
    setState(() {
      selectedFeedingType = feedingType;
    });
  }

  void handleAnalyzeButtonTap() {
    debugPrint('수유 기록 분석');
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '수유 기록',
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
              const Text(
                '수유 방식과 수유량을\n기록해주세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                '기록된 데이터는 AI 분석에 활용됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
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

              const Text(
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
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: feedingAmountController,

                  keyboardType: TextInputType.number,

                  // ✅ 숫자만 입력 가능
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],

                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: handleAnalyzeButtonTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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

  Widget _buildFeedingTypeButton(String feedingType) {
    final bool isSelected = selectedFeedingType == feedingType;

    return GestureDetector(
      onTap: () => handleFeedingTypeTap(feedingType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : Colors.white,
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