import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

import '../../core/services/baby_service.dart';
import '../detail/diaper_record_service.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';
import 'today_summary.dart';
import '../detail/feeding_record_page.dart';
import '../detail/temperature_record_page.dart';
import '../detail/diaper_record_page.dart';
import '../detail/sleep_record_page.dart';
import '../detail/eusick_page.dart';
import '../detail/skin_analysis_page.dart';
import '../detail/vaccination_page.dart';
// 수면 소음 측정 페이지 임포트
import '../detail/noise_test_page.dart';
import '../detail/growth/growth_record_page.dart';

/// [HomePage]
/// 역할: 아이의 현재 상태 요약, AI 분석 정보, 오늘 기록을 보여주는 메인 대시보드
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 온보딩에서 등록한 아이. 아직 못 불러왔으면 null입니다.
  Baby? _baby;

  /// 이름을 못 불러온 동안 쓸 표시값. 빈 칸을 두면 화면이 흔들려 보입니다.
  static const String _fallbackName = '우리 아이';

  String get _babyName => _baby?.name ?? _fallbackName;

  @override
  void initState() {
    super.initState();
    _loadBaby();
  }

  /// 오늘의 기록 요약. 아직 못 읽었으면 비어 있습니다.
  TodaySummary _today = TodaySummary.empty;

  /// 요약을 불러오는 중인지. 불러오기 전에 '기록 없음'을 보여주면
  /// 실제로 기록이 있는데도 없다고 오해하게 됩니다.
  bool _loadingToday = true;

  Future<void> _loadBaby() async {
    try {
      final baby = await BabyService.loadCurrent();
      if (!mounted) return;
      setState(() => _baby = baby);

      if (baby != null) await _loadToday(baby.id);
    } catch (e) {
      // 이름을 못 불러와도 홈은 보여줍니다. 기록 기능은 각 화면에서 다시 조회합니다.
      debugPrint('아이 정보 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingToday = false);
    }
  }

  /// 오늘의 마지막 기록 네 가지를 함께 읽습니다.
  /// 서로 독립이라 순서대로 기다릴 이유가 없어 동시에 요청합니다.
  Future<void> _loadToday(String babyId) async {
    try {
      final results = await Future.wait([
        FeedingRecordService.loadRecent(babyId, limit: 5),
        TemperatureRecordService.loadRecent(babyId, limit: 5),
        DiaperRecordService.loadRecent(babyId, limit: 5),
        SleepRecordService.loadRecent(babyId, limit: 5),
      ]);

      if (!mounted) return;
      setState(() {
        _today = TodaySummary.from(
          feedings: results[0] as List<FeedingRecord>,
          temperatures: results[1] as List<TemperatureRecord>,
          diapers: results[2] as List<DiaperRecord>,
          sleeps: results[3] as List<SleepRecord>,
        );
      });
    } catch (e) {
      // 요약을 못 읽어도 홈의 다른 기능은 그대로 씁니다.
      debugPrint('오늘 기록 조회 실패: $e');
    }
  }

  /// 타일 부제목. 아직 불러오는 중이면 비우고, 기록이 없으면 그렇다고 적습니다.
  String _tileSubtitle(String? value) {
    if (_loadingToday) return '불러오는 중…';
    return value ?? '기록 없음';
  }

  // --- 테마 및 스타일 상수 ---
  static const Color primaryColor = AppColors.primary;
  static const Color backgroundColor = Color(0xFFF9F9F9);
  static const Color surfaceColor = Colors.white;
  static const Color onSurfaceColor = Color(0xFF1A1C1C);
  static const Color secondaryTextColor = Color(0xFF555F6A);
  static const Color successColor = Color(0xFF31E193);

  // --- 이벤트 처리 / 네비게이션 함수 ---

  void handleFeedingRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FeedingRecordPage()),
    );
  }

  void handleTemperatureRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TemperatureRecordPage()),
    );
  }

  void handleDiaperRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiaperRecordPage()),
    );
  }

  // ★ 수정: [수면] 버튼을 누를 때 띄우던 모드 선택창을 없애고 수면 기록 페이지로 즉시 이동시킵니다.
  void handleSleepRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SleepRecordPage()),
    );
  }

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

  // [소음] 버튼은 화면 이동만 합니다.
  // 측정 시작은 소음 화면에서 밤잠/낮잠을 고른 뒤에 해야 하므로,
  // 여기서 미리 시작하면 사용자가 고를 틈이 없습니다.
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

  void handleGrowthRecordTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GrowthRecordPage()),
    );
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
              childAspectRatio: 0.72,
              children: [
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.baby_changing_station,
                  iconColor: primaryColor,
                  title: '수유',
                  subtitle: _tileSubtitle(_today.feedingLabel),
                  onTap: () => handleFeedingRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.thermostat,
                  iconColor: Colors.red,
                  title: '체온',
                  subtitle: _tileSubtitle(_today.temperatureLabel),
                  onTap: () => handleTemperatureRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.opacity,
                  iconColor: Colors.amber,
                  title: '배변',
                  subtitle: _tileSubtitle(_today.diaperLabel),
                  onTap: () => handleDiaperRecordTap(context),
                ),
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.bedtime,
                  iconColor: Colors.indigo,
                  title: '수면',
                  subtitle: _tileSubtitle(_today.sleepLabel),
                  onTap: () => handleSleepRecordTap(context), // 깔끔하게 직통 연동
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
                  icon: Icons.show_chart,
                  iconColor: Colors.blue,
                  title: '성장',
                  subtitle: 'WHO 성장곡선',
                  onTap: () => handleGrowthRecordTap(context),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildBentoGrid(context),
            const SizedBox(height: 120),
          ],
        ),
      ),
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
          Text(
            _babyName,
            style: const TextStyle(
              color: onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 조사(은/는)를 피해 '의'를 씁니다. 받침 유무와 무관하게 자연스럽고,
        // 아이가 지금 무엇을 하는지 앱은 알 수 없으므로 단정하지 않습니다.
        Text(
          '$_babyName의\n오늘 하루',
          style: const TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w900,
            color: onSurfaceColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '기록을 남기면 상태를 분석해 드려요',
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
                  '오늘의 수유',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_today.feeding != null)
                const Icon(Icons.circle, size: 8, color: successColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _feedingHeadline,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: onSurfaceColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _feedingDetail,
                  style: const TextStyle(color: secondaryTextColor),
                ),
              ),
              const Icon(Icons.schedule, color: primaryColor, size: 32),
            ],
          ),
        ],
      ),
    );
  }

  /// 수유 카드의 큰 문구.
  ///
  /// '다음 수유까지 N시간' 같은 예측은 넣지 않습니다. 아이마다 수유 간격이
  /// 다르고 그 기준을 정한 바가 없어, 숫자를 지어내는 것이 되기 때문입니다.
  String get _feedingHeadline {
    if (_loadingToday) return '기록을 불러오는 중이에요';
    final f = _today.feeding;
    if (f == null) return '오늘 수유 기록이 없어요';

    final elapsed = DateTime.now().difference(f.fedAt);
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}분 전에 먹었어요';
    return '${elapsed.inHours}시간 전에 먹었어요';
  }

  /// 카드 아래 보조 문구.
  String get _feedingDetail {
    if (_loadingToday) return '';
    final f = _today.feeding;
    if (f == null) return '수유 타일을 눌러 기록을 남겨보세요';

    final at = f.fedAt;
    final period = at.hour < 12 ? '오전' : '오후';
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final time = '$period $h:${at.minute.toString().padLeft(2, '0')}';
    return '마지막 수유: $time · ${f.summary}';
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => handleNoiseTestTap(context), // 벤토 품질 클릭 시 소음 케어로 즉시 이동
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