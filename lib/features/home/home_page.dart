import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../detail/feeding_record_page.dart';
import '../detail/temperature_record_page.dart';
import '../detail/diaper_record_page.dart';
import '../detail/sleep_record_page.dart';
import '../detail/eusick_page.dart';
import '../detail/skin_analysis_page.dart';
import '../detail/cry_analysis_page.dart';
import '../detail/vaccination_page.dart';
// ★ 수면 소음 측정 페이지 임포트 추가
import '../detail/noise_test_page.dart';

/// [HomePage]
/// 역할: 아이의 현재 상태 요약, AI 분석 정보, 오늘 기록을 보여주는 메인 대시보드
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // --- 테마 및 스타일 상수 ---
  static const Color primaryColor = Color(0xFF0059B9);
  static const Color backgroundColor = Color(0xFFF9F9F9);
  static const Color surfaceColor = Colors.white;
  static const Color onSurfaceColor = Color(0xFF1A1C1C);
  static const Color secondaryTextColor = Color(0xFF555F6A);
  static const Color successColor = Color(0xFF31E193);

  // --- 이벤트 처리 / 네비게이션 함수 ---

  void handleSettingsTap(BuildContext context) {
    navigateToSettings(context);
  }

  void handleRecordStateTap(BuildContext context) {
    debugPrint("Record state tapped");
    // 기록 입력용 바텀시트/페이지 연결 예정
  }

  // 수유 기록 페이지 이동
  void handleFeedingRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FeedingRecordPage()),
    );
  }

  // 체온 기록 페이지 이동 ✅ 수정
  void handleTemperatureRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TemperatureRecordPage()),
    );
  }

  // 배변 기록 페이지 이동 ✅
  void handleDiaperRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiaperRecordPage()),
    );
  }

  // 수면 기록 페이지 이동
  void handleSleepRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SleepRecordPage()),
    );
  }

  // 이유식 성분 분석 페이지 이동
  void handleEusickTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EusickPage()),
    );
  }

  void handleVaccinationTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VaccinationPage()),
    );
  }

  void handleNoiseTestTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NoiseTestPage()),
    );
  }

  void handleSkinAnalysisTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SkinAnalysisPage()),
    );
  }

  void handleCryAnalysisTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CryAnalysisPage()),
    );
  }

  void navigateToSettings(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildTopAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildHeroSection(),
            const SizedBox(height: 32),
            _buildAIInsightCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('오늘의 기록'),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.95,
              children: [
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.baby_changing_station,
                  iconColor: primaryColor,
                  title: '수유',
                  subtitle: '분유 · 160ml',
                  onTap: () => handleFeedingRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.thermostat,
                  iconColor: Colors.red,
                  title: '체온',
                  subtitle: '36.5°C',
                  onTap: () => handleTemperatureRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.opacity,
                  iconColor: Colors.amber,
                  title: '배변',
                  subtitle: '소변',
                  onTap: () => handleDiaperRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.bedtime,
                  iconColor: Colors.indigo,
                  title: '수면',
                  subtitle: '오전 11:20 ~ 오후 01:00',
                  onTap: () => handleSleepRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.restaurant,
                  iconColor: Colors.green,
                  title: '이유식',
                  subtitle: 'AI 성분 분석',
                  onTap: () => handleEusickTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.vaccines,
                  iconColor: Colors.teal,
                  title: '예방접종',
                  subtitle: '접종 일정',
                  onTap: () => handleVaccinationTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.mic,
                  iconColor: Colors.deepPurple,
                  title: '소음',
                  subtitle: '측정하기',
                  onTap: () => handleNoiseTestTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.face_retouching_natural,
                  iconColor: Colors.pink,
                  title: '피부',
                  subtitle: 'AI 판단',
                  onTap: () => handleSkinAnalysisTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.record_voice_over,
                  iconColor: Colors.deepOrange,
                  title: '울음소리',
                  subtitle: '의미 분석',
                  onTap: () => handleCryAnalysisTap(context),
                ),
              ],
            ),

            const SizedBox(height: 24),
            // ★ 수정: buildBentoGrid에 context를 넘겨줍니다.
            _buildBentoGrid(context),
            const SizedBox(height: 120),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(context),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.8),
      elevation: 0,
      title: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFD9E3F1),
            child: Icon(Icons.child_care, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            '아이이름',
            style: TextStyle(
              color: onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.grey),
          onPressed: () => handleSettingsTap(context),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'baby(아이이름)is\nsleeping very well',
          style: TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w900,
            color: onSurfaceColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '아이이름은(는) 지금 아주 잘 자고 있어요',
          style: TextStyle(fontSize: 16, color: secondaryTextColor),
        ),
      ],
    );
  }

  Widget _buildAIInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FEEDING AI',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 8, color: successColor),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: onSurfaceColor,
              ),
              children: [
                TextSpan(text: '다음 수유까지 '),
                TextSpan(
                  text: '1시간',
                  style: TextStyle(color: primaryColor),
                ),
                TextSpan(text: ' 남았어요'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '마지막 수유: 오전 10:30',
                style: TextStyle(color: secondaryTextColor),
              ),
              Icon(Icons.schedule, color: primaryColor, size: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareRecordButton({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: secondaryTextColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ★ 수정: context를 매개변수로 받고 수면 품질 클릭 시 NoiseTestPage로 이동
  Widget _buildBentoGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NoiseTestPage()),
              );
            },
            child: _buildBentoCard(
              icon: Icons.bedtime,
              title: '수면 품질',
              value: '94%',
              color: primaryColor.withValues(alpha: 0.1),
              textColor: primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildBentoCard(
            icon: Icons.speed,
            title: '활동량',
            value: '낮음',
            color: const Color(0xFFD9E3F1).withValues(alpha: 0.5),
            textColor: secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: () => handleRecordStateTap(context),
        backgroundColor: primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '아이 상태 기록하기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Home', true),
          _navItem(Icons.analytics, 'Insights', false),
          _navItem(Icons.medical_services, 'Health', false),
          _navItem(Icons.more_horiz, 'More', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? primaryColor : Colors.grey),
        Text(
          label,
          style: TextStyle(
            color: isActive ? primaryColor : Colors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          '전체보기',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
