import 'package:flutter/material.dart';

import '../advice/ask_fab.dart';

import '../../core/services/refresh_signal.dart';
import '../../core/constants/app_colors.dart';

import '../../core/services/baby_service.dart';
import '../detail/assessment/temperature_rules.dart' show ageInMonthsAt;
import '../detail/diaper_record_service.dart';
import '../feeding_reminder/next_feeding_card.dart';
import '../../routes/app_routes.dart';
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
  /// 이 탭이 다시 보일 때 울리는 신호. 없으면 처음 한 번만 읽습니다.
  ///
  /// [IndexedStack]이라 화면이 살아 있는 채로 숨겨져 initState가 한 번만
  /// 돕니다. 이게 없으면 방금 남긴 기록이 '없음'으로 보이고, 자정을 넘겨
  /// 돌아와도 어제 값이 그대로 있습니다.
  final RefreshSignal? refresh;

  const HomePage({super.key, this.refresh});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 상담 단추를 언제 보일지.
  ///
  /// **두 방식을 여기서 바꿉니다.**
  /// - `visibleAtTop: false` — 평소엔 없다가 아래로 끌면 나타납니다.
  /// - `visibleAtTop: true`  — 맨 위에서는 보이고 내려 읽으면 비킵니다.
  final AskFabVisibility _askVisibility =
      AskFabVisibility(visibleAtTop: false);

  /// 온보딩에서 등록한 아이. 아직 못 불러왔으면 null입니다.
  Baby? _baby;

  /// 이름을 못 불러온 동안 쓸 표시값. 빈 칸을 두면 화면이 흔들려 보입니다.
  static const String _fallbackName = '우리 아이';

  String get _babyName => _baby?.name ?? _fallbackName;

  @override
  void initState() {
    super.initState();
    _loadBaby();
    widget.refresh?.addListener(_loadBaby);
  }

  @override
  void dispose() {
    _askVisibility.dispose();
    widget.refresh?.removeListener(_loadBaby);
    super.dispose();
  }

  /// 오늘의 기록 요약. 아직 못 읽었으면 비어 있습니다.
  TodaySummary _today = TodaySummary.empty;

  /// 요약을 불러오는 중인지. 불러오기 전에 '기록 없음'을 보여주면
  /// 실제로 기록이 있는데도 없다고 오해하게 됩니다.
  bool _loadingToday = true;

  /// **날짜와 무관하게** 가장 최근 수유 시각. 다음 수유 카드가 이걸 씁니다.
  ///
  /// `_today.feeding`을 쓰면 안 됩니다. 그쪽은 오늘 것만 담으므로 자정을
  /// 넘기는 순간 null이 되고, 밤 11시에 먹인 아이가 새벽 1시에는 "수유를
  /// 기록해 주세요"로 되돌아갑니다. 알림 예약까지 함께 취소됩니다 —
  /// 하필 이 기능이 필요한 시간대입니다.
  DateTime? _lastFedAt;

  /// 오늘 기록을 **못 읽었는지**. 기록이 없는 것과 다릅니다.
  ///
  /// 예전에는 예외를 debugPrint만 하고 넘어가, 타일에 '기록 없음'이 떴습니다.
  /// 기록이 정말 없을 때와 글자가 같아 구별할 수 없었습니다.
  bool _todayFailed = false;

  /// 이 조회가 몇 번째인지.
  ///
  /// 탭을 다시 누르거나 앱이 앞으로 나오면 [RefreshSignal]이 울리는데, 앞
  /// 조회가 끝났는지는 보지 않습니다. 그래서 두 조회가 겹칠 수 있고,
  /// **늦게 온 실패가 방금 성공한 결과를 덮었습니다** — 아홉 타일이 전부
  /// '불러오지 못함'이 되고 스스로 낫지도 않았습니다.
  ///
  /// 마지막 조회의 결과만 반영합니다.
  int _loadGen = 0;

  Future<void> _loadBaby() async {
    final gen = ++_loadGen;
    setState(() {
      _loadingToday = true;
      _todayFailed = false;
    });

    try {
      final baby = await BabyService.loadCurrent();
      if (!mounted || gen != _loadGen) return;
      setState(() => _baby = baby);

      if (baby != null) await _loadToday(baby.id, gen);
    } catch (e) {
      // 이름을 못 불러와도 홈은 보여줍니다. 기록 기능은 각 화면에서 다시 조회합니다.
      if (mounted && gen == _loadGen) setState(() => _todayFailed = true);
      debugPrint('아이 정보 조회 실패: $e');
    } finally {
      if (mounted && gen == _loadGen) setState(() => _loadingToday = false);
    }
  }

  /// 오늘의 마지막 기록 네 가지를 함께 읽습니다.
  /// 서로 독립이라 순서대로 기다릴 이유가 없어 동시에 요청합니다.
  Future<void> _loadToday(String babyId, int gen) async {
    try {
      final results = await Future.wait([
        FeedingRecordService.loadRecent(babyId, limit: 5),
        TemperatureRecordService.loadRecent(babyId, limit: 5),
        DiaperRecordService.loadRecent(babyId, limit: 5),
        SleepRecordService.loadRecent(babyId, limit: 5),
      ]);

      final feedings = results[0] as List<FeedingRecord>;

      if (!mounted || gen != _loadGen) return;
      setState(() {
        // 성공했으면 앞선 실패 표시를 지웁니다.
        _todayFailed = false;
        // loadRecent가 최신순으로 주므로 첫 항목이 가장 최근입니다.
        _lastFedAt = feedings.isEmpty ? null : feedings.first.fedAt;
        _today = TodaySummary.from(
          feedings: feedings,
          temperatures: results[1] as List<TemperatureRecord>,
          diapers: results[2] as List<DiaperRecord>,
          sleeps: results[3] as List<SleepRecord>,
        );
      });
    } catch (e) {
      // 요약을 못 읽어도 홈의 다른 기능은 그대로 씁니다. 다만 못 읽었다는
      // 사실은 감추지 않습니다.
      if (mounted && gen == _loadGen) setState(() => _todayFailed = true);
      debugPrint('오늘 기록 조회 실패: $e');
    }
  }

  /// 타일 부제목. 불러오는 중·못 읽음·기록 없음을 각각 다르게 적습니다.
  String _tileSubtitle(String? value) {
    if (_loadingToday) return '불러오는 중…';
    if (_todayFailed) return '불러오지 못함';
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
      // 스크롤 방향을 단추에 알립니다. 컨트롤러가 아니라 알림을 쓰는 까닭은
      // [AskFabVisibility]에 적어 뒀습니다 — 맨 위에서 아래로 끌 때
      // 안드로이드에서는 위치가 움직이지 않아 컨트롤러가 조용합니다.
      // 목록 길이가 정해질 때와, 손가락이 움직일 때. 둘은 서로 다른 알림
      // 계층이라 따로 받습니다.
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _askVisibility.updateMetrics(notification.metrics);
          return false; // 다른 곳도 이 알림을 받아야 합니다.
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _askVisibility.update(notification);
            return false;
          },
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildHeroSection(),
            const SizedBox(height: 32),
            NextFeedingCard(
              lastFedAt: _lastFedAt,
              babyName: _baby?.name,
              ageInMonths: _baby == null
                  ? null
                  : ageInMonthsAt(_baby!.birthDate, DateTime.now()),
              loading: _loadingToday,
              failed: _todayFailed,
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('오늘의 기록'),
            // 못 읽었을 때는 그렇다고 적고 다시 시도할 길을 둡니다. 아래
            // 타일은 '불러오지 못함'을 달고 있어 눌러도 되지만, 여기서
            // 한 번에 다시 읽는 편이 빠릅니다.
            if (_todayFailed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '오늘 기록을 불러오지 못했어요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadBaby,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // 부제목 한 줄이 늘어 0.72로는 큰 글씨에서 넘쳤습니다(1.3배에서 9.7px).
              childAspectRatio: 0.64,
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
                  icon: Icons.thermostat,
                  iconColor: Colors.red,
                  title: '체온',
                  subtitle: _tileSubtitle(_today.temperatureLabel),
                  onTap: () => handleTemperatureRecordTap(context),
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
                  icon: Icons.show_chart,
                  iconColor: Colors.blue,
                  title: '성장',
                  subtitle: 'WHO 성장곡선',
                  onTap: () => handleGrowthRecordTap(context),
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
                  icon: Icons.vaccines,
                  iconColor: Colors.teal,
                  title: '예방접종',
                  subtitle: '접종 일정',
                  onTap: () => handleVaccinationTap(context),
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

            // 떠 있는 상담 단추가 마지막 카드를 덮지 않게 비워 둡니다.
            //
            // 예전에는 여기에 120이 더 있었습니다. 홈이 자기 하단 바를 직접
            // 그리던 시절의 자리인데, 지금은 [MainShell]이 그립니다 — 홈
            // 본문은 이미 그 위에서 끝나므로 그만큼이 통째로 빈 공간이었습니다.
            const SizedBox(height: AskFab.reservedHeight),
            ],
          ),
          ),
        ),
      ),
      // 오른쪽 아래에 동그랗게. 홈은 기록하러 들어가기 전에 머무는 곳이라,
      // 여기서는 눈에 띄어도 하던 일을 가로막지 않습니다.
      floatingActionButton: AskFab(visibility: _askVisibility),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.colors.surface.withValues(alpha: 0.8),
      elevation: 0,
      // 사진과 이름을 누르면 마이페이지로 갑니다. 아이 정보를 고치는 자리가
      // 거기 하나뿐이라, 이름을 누른 사람이 기대하는 곳입니다.
      title: InkWell(
        onTap: _openMyPage,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 18, color: secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }

  /// 마이페이지에 다녀옵니다.
  ///
  /// 아이 이름·생년월일이 바뀌었을 수 있어 돌아오면 다시 읽습니다. 생년월일은
  /// 개월 수의 근거라 수유 알림의 기본 간격 제안에도 쓰입니다.
  Future<void> _openMyPage() async {
    await Navigator.pushNamed(context, AppRoutes.mypage);
    if (mounted) await _loadBaby();
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
            // 아주 큰 글씨에서는 칸을 넘기지 않도록 줄여 담습니다. 격자라
            // 타일 높이가 고정이고, 넘치면 붉은 줄무늬가 뜹니다.
            Flexible(
              child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 색을 비워 두면 테마의 글씨색을 물려받습니다. 예전에는 타일
              // 바탕만 밝은 색으로 고정돼 있어, 어두운 테마에서 밝은 바탕에
              // 밝은 글씨가 겹쳐 대비 1.01:1로 아무것도 보이지 않았습니다.
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: context.colors.textPrimary,
              ),
              ),
            ),
            const SizedBox(height: 2),
            // **부제목을 그립니다.** [_tileSubtitle]이 '불러오는 중…'·
            // '불러오지 못함'·'기록 없음'을 갈라 만드는데, 그것을 받아 놓고
            // 그리지 않아 **한 번도 화면에 닿은 적이 없었습니다.** 그래서
            // 홈에서는 조회 실패와 기록 없음이 똑같아 보였습니다 — 이 앱이
            // 스스로 세운 첫 번째 원칙이 정작 홈에서 지켜지지 않았습니다.
            //
            // 한 줄로 자릅니다. 타일이 3열 격자라 두 줄이 되면 넘칩니다.
            Flexible(
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
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