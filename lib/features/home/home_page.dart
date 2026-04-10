import 'package:flutter/material.dart';

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

  // --- [handle] 이벤트 처리 함수 (이벤트 발생 시 실행) ---

  /// 설정 버튼 클릭 시 처리
  void _handleSettingsTap(BuildContext context) {
    debugPrint("Settings tapped");
    // [navigateTo] 컨벤션: Navigator.pushNamed(context, AppRoutes.settings);
  }

  /// 새로운 아이 상태 기록 버튼 클릭 시 처리
  void _handleRecordStateTap(BuildContext context) {
    debugPrint("Record state tapped");
    // [show] 컨벤션: 기록 입력을 위한 바텀 시트 표시 로직 예정
  }

  /// 특정 기록 항목 클릭 시 상세 화면으로 이동
  void _handleRecordItemTap(BuildContext context, String title) {
    debugPrint("Selected record: $title");
    // [navigateTo] 컨벤션: Navigator.pushNamed(context, AppRoutes.detail);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // 1. [build] 상단 앱바: 아기 프로필과 설정 진입점
      appBar: _buildTopAppBar(context),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // 2. [build] 히어로 섹션: 현재 아기의 상태 문구 표시
            _buildHeroSection(),
            const SizedBox(height: 32),

            // 3. [build] AI 인사이트 카드: 수유 타이머 등 AI 분석 정보 (fetch 예정)
            _buildAIInsightCard(),
            const SizedBox(height: 32),

            // 4. [build] 오늘의 기록 섹션: 타임라인 형태의 활동 기록
            _buildSectionHeader('오늘의 기록'),
            const SizedBox(height: 16),
            _buildRecordItem(
              context: context,
              icon: Icons.baby_changing_station,
              iconColor: primaryColor,
              title: '수유 (분유)',
              subtitle: '오전 10:30 · 160ml',
            ),
            _buildRecordItem(
              context: context,
              icon: Icons.thermostat,
              iconColor: Colors.red,
              title: '체온',
              subtitle: '오전 09:15 · 36.5°C',
            ),
            _buildRecordItem(
              context: context,
              icon: Icons.opacity,
              iconColor: Colors.amber,
              title: '배변',
              subtitle: '오전 08:40 · 소변',
            ),
            const SizedBox(height: 24),

            // 5. [build] 벤토 그리드: 수면 품질 및 활동량 요약 정보
            _buildBentoGrid(),

            const SizedBox(height: 120), // 하단 버튼 공간 확보를 위한 여백
          ],
        ),
      ),

      // 6. [build] 플로팅 버튼: 빠른 기록 추가 진입점
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(context),

      // 7. [build] 하단 네비게이션 바: 주요 메뉴 이동
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- [build] UI 구성 함수들 ---

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.8),
      elevation: 0,
      title: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFD9E3F1),
            backgroundImage: NetworkImage('https://via.placeholder.com/150'),
          ),
          const SizedBox(width: 12),
          const Text('아이이름', style: TextStyle(color: onSurfaceColor, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.grey),
          onPressed: () => _handleSettingsTap(context),
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
          style: TextStyle(fontSize: 32, height: 1.2, fontWeight: FontWeight.w900, color: onSurfaceColor),
        ),
        SizedBox(height: 8),
        Text('아이이름은(는) 지금 아주 잘 자고 있어요', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
      ],
    );
  }

  Widget _buildAIInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: const Text('FEEDING AI', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 8, color: successColor),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onSurfaceColor),
              children: [
                TextSpan(text: '다음 수유까지 '),
                TextSpan(text: '1시간', style: TextStyle(color: primaryColor)),
                TextSpan(text: ' 남았어요'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('마지막 수유: 오전 10:30', style: TextStyle(color: secondaryTextColor)),
              Icon(Icons.schedule, color: primaryColor, size: 32),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRecordItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () => _handleRecordItemTap(context, title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF3F3F4), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: secondaryTextColor, fontSize: 14)),
                ],
              ),
            ),
            const Row(
              children: [
                Text('정상', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.circle, size: 8, color: Colors.green),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBentoGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildBentoCard(
            icon: Icons.bedtime,
            title: '수면 품질',
            value: '94%',
            color: primaryColor.withOpacity(0.1),
            textColor: primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildBentoCard(
            icon: Icons.speed,
            title: '활동량',
            value: '낮음',
            color: const Color(0xFFD9E3F1).withOpacity(0.5),
            textColor: secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({required IconData icon, required String title, required String value, required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: onSurfaceColor)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: () => _handleRecordStateTap(context),
        backgroundColor: primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('아이 상태 기록하기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
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
        Text(label, style: TextStyle(color: isActive ? primaryColor : Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('전체보기', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      ],
    );
  }
}