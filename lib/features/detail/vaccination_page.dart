import 'package:flutter/material.dart';

class VaccinationPage extends StatelessWidget {
  const VaccinationPage({super.key});

  static const Color primaryColor = Color(0xFF14B8A6);
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);

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
          '예방접종',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildNextVaccinationCard(),
          const SizedBox(height: 24),
          _buildProgressCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('완료한 접종'),
          const SizedBox(height: 12),
          _buildVaccinationItem(
            title: 'BCG',
            subtitle: '생후 4주 이내',
            isCompleted: true,
          ),
          _buildVaccinationItem(
            title: 'B형간염 1차',
            subtitle: '출생 직후',
            isCompleted: true,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('예정된 접종'),
          const SizedBox(height: 12),
          _buildVaccinationItem(
            title: 'DTaP 1차',
            subtitle: '생후 2개월',
            isCompleted: false,
          ),
          _buildVaccinationItem(
            title: '소아마비 1차',
            subtitle: '생후 2개월',
            isCompleted: false,
          ),
          _buildVaccinationItem(
            title: 'MMR',
            subtitle: '생후 12~15개월',
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNextVaccinationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.vaccines, color: primaryColor, size: 36),
          SizedBox(height: 16),
          Text(
            '다음 접종',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'DTaP 1차',
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '생후 2개월 시기 · D-15',
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE0F2F1),
            child: Icon(Icons.check, color: primaryColor),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '접종 진행률',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '2 / 5 완료',
                  style: TextStyle(color: secondaryTextColor, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            '40%',
            style: TextStyle(
              color: primaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildVaccinationItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? primaryColor.withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? primaryColor : secondaryTextColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            isCompleted ? '완료' : '예정',
            style: TextStyle(
              color: isCompleted ? primaryColor : secondaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
