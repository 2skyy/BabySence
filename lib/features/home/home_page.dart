import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

import '../../core/services/baby_service.dart';
import '../detail/assessment/temperature_rules.dart' show ageInMonthsAt;
import '../detail/diaper_record_service.dart';
import '../feeding_reminder/next_feeding_card.dart';
import '../detail/feeding_record_service.dart';
import '../detail/sleep_record_service.dart';
import '../detail/temperature_record_service.dart';
import 'today_summary.dart';
import '../detail/feeding_record_page.dart';
import '../detail/temperature_record_page.dart';
import '../detail/diaper_record_page.dart';
import '../detail/sleep_record_page.dart';
import '../detail/skin_analysis_page.dart';
import '../detail/care/care_record_page.dart';
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
  Color get backgroundColor => context.colors.background;
  Color get surfaceColor => context.colors.surface;
  Color get onSurfaceColor => context.colors.textPrimary;
  Color get secondaryTextColor => context.colors.textSecondary;

  // --- 이벤트 처리 / 네비게이션 함수 ---

  /// 기록 화면에 다녀오면 홈을 다시 읽습니다.
  ///
  /// 예전에는 다녀와도 그대로여서 방금 남긴 기록이 홈에 없었습니다. 표시가
  /// 낡는 것에 그치지 않고, 다음 수유 카드가 옛 기록으로 알림 시각을 잡습니다.
  Future<void> _openAndRefresh(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _loadBaby();
  }

  Future<void> handleFeedingRecordTap(BuildContext context) =>
      _openAndRefresh(context, const FeedingRecordPage());

  Future<void> handleTemperatureRecordTap(BuildContext context) =>
      _openAndRefresh(context, const TemperatureRecordPage());

  Future<void> handleDiaperRecordTap(BuildContext context) =>
      _openAndRefresh(context, const DiaperRecordPage());

  Future<void> handleSleepRecordTap(BuildContext context) =>
      _openAndRefresh(context, const SleepRecordPage());

  Future<void> handleVaccinationTap(BuildContext context) =>
      _openAndRefresh(context, const VaccinationPage());

  Future<void> handleCareRecordTap(BuildContext context) =>
      _openAndRefresh(context, const CareRecordPage());

  // [소음] 버튼은 화면 이동만 합니다. 측정 시작은 소음 화면에서
  // 밤잠/낮잠을 고른 뒤에 해야 하므로, 여기서 미리 시작하면
  // 사용자가 고를 틈이 없습니다.
  Future<void> handleNoiseTestTap(BuildContext context) =>
      _openAndRefresh(context, const NoiseTestPage());

  Future<void> handleSkinAnalysisTap(BuildContext context) =>
      _openAndRefresh(context, const SkinAnalysisPage());

  Future<void> handleGrowthRecordTap(BuildContext context) =>
      _openAndRefresh(context, const GrowthRecordPage());

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
            NextFeedingCard(
              lastFedAt: _today.feeding?.fedAt,
              ageInMonths: _baby == null
                  ? null
                  : ageInMonthsAt(_baby!.birthDate, DateTime.now()),
              loading: _loadingToday,
            ),
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
                _buildSquareRecordButton(
                  context: context,
                  icon: Icons.medication_outlined,
                  iconColor: Colors.redAccent,
                  title: '약 · 병원',
                  subtitle: '투약과 진료',
                  onTap: () => handleCareRecordTap(context),
                ),
              ],
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.colors.surface.withValues(alpha: 0.8),
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFD9E3F1),
            child: Icon(Icons.child_care, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            _babyName,
            style: TextStyle(
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
          style: TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w900,
            color: onSurfaceColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '기록을 남기면 상태를 분석해 드려요',
          style: TextStyle(fontSize: 16, color: secondaryTextColor),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // 타일 바탕과 같은 색이면 원판이 보이지 않습니다.
                color: context.colors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              // 색을 비워 두면 테마의 글씨색을 물려받습니다. 예전에는 타일
              // 바탕만 밝은 색으로 고정돼 있어, 어두운 테마에서 밝은 바탕에
              // 밝은 글씨가 겹쳐 대비 1.01:1로 아무것도 보이지 않았습니다.
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}