import 'package:flutter/material.dart';

import '../../core/widgets/stale_notice.dart';

import '../../core/services/refresh_signal.dart';

import '../../core/widgets/common_app_bar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
// 시간을 '7시간 30분'으로 쓰는 것은 분석 탭이 이미 갖고 있습니다. 같은 값을
// 두 화면이 다르게 적으면 같은 잠이 다른 잠으로 보입니다.
import '../analysis/weekly_summary.dart' show formatDuration;
import 'day_ring.dart';
import 'period_records.dart';
import 'recent_records.dart';
import 'record_period.dart';

/// 기록 탭 — **지금까지 남긴 기록만** 봅니다.
///
/// 수유 화면에서는 수유만, 배변 화면에서는 배변만 보여 "어젯밤에 무슨 일이
/// 있었는지"를 이어서 볼 수 없습니다. 그것을 잇는 자리입니다.
///
/// 하루를 24시간 원으로 그리고, 일·주·월 중 고른 눈금만큼 늘어놓습니다.
/// 목록만으로는 "요즘 밤에 몇 번 깨는가"가 보이지 않습니다 — 같은 새벽 3시가
/// 줄글로는 스무 줄 떨어져 있고, 원 위에서는 같은 자리에 겹칩니다.
///
/// 기록하러 들어가는 입구는 두지 않습니다. 예전에는 여기에도 5칸 격자가
/// 있었는데 홈의 9칸과 겹쳤고, 홈보다 적어서 여기서 기록한다고 배운 사람은
/// 성장·약병원을 찾지 못했습니다. 입구는 홈 한 곳입니다.
class RecordsPage extends StatefulWidget {
  /// 이 탭이 다시 보일 때 울리는 신호. 없으면 처음 한 번만 읽습니다.
  ///
  /// [IndexedStack]이라 화면이 살아 있는 채로 숨겨져 initState가 한 번만
  /// 돕니다. 이게 없으면 방금 남긴 기록이 '없음'으로 보이고, 자정을 넘겨
  /// 돌아와도 어제 값이 그대로 있습니다.
  final RefreshSignal? refresh;

  /// 한 기간을 읽는 일. **테스트에서만 갈아 끼웁니다.**
  ///
  /// 이 화면에서 가장 틀리기 쉬운 것은 계산이 아니라 조립부였습니다 —
  /// 눈금 전환, 기간 이동, 실패 뒤의 화면. 그 자리들이 조회를 거치므로
  /// Supabase 없이는 한 줄도 돌려 볼 수 없었고, 실제로 결함 둘이 거기서
  /// 났습니다. 조회만 밖에서 받으면 화면 전체를 띄워 볼 수 있습니다.
  final PeriodRecordsLoad loader;

  /// 지금 몇 시인지. **테스트에서만 갈아 끼웁니다.**
  ///
  /// 이 화면은 '오늘'을 여섯 자리에서 묻습니다 — 처음 펼 날, 자정 따라가기,
  /// 기간을 옮길 때 고를 날, 다음 단추를 죽일지, 어느 원이 오늘인지.
  /// 시계를 직접 부르면 그중 무엇도 돌려 볼 수 없어, 자정을 넘겼을 때의
  /// 동작이 통째로 검사 밖에 있었습니다.
  final DateTime Function() clock;

  const RecordsPage({
    super.key,
    this.refresh,
    this.loader = loadPeriodRecords,
    this.clock = DateTime.now,
  });

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  /// 눈금과 보고 있는 하루. **이 둘만이 상태**이고 기간은 여기서 나옵니다.
  ///
  /// 기간을 따로 들고 있으면 눈금을 바꿀 때마다 둘을 같이 맞춰야 하고, 한쪽만
  /// 고친 자리에서 머리글과 원이 서로 다른 날을 말하게 됩니다.
  PeriodMode _mode = PeriodMode.week;
  late DateTime _selectedDay;

  RecordPeriod get _period => RecordPeriod.of(_mode, _selectedDay);

  /// **보고 있는 기간 안의** 기록만 담습니다.
  List<RecentRecord> _records = const [];

  /// 기간의 날 수만큼. 기록이 없는 날도 빈 채로 자리를 지킵니다.
  List<DayPattern> _patterns = const [];

  /// 지금 손에 든 [_records]·[_patterns]가 **어느 기간의 것인지**.
  ///
  /// 눈금이나 날짜는 누르는 즉시 바뀌지만 기록은 조회가 끝나야 옵니다. 이걸
  /// 두지 않으면 그 사이에 '2026년 8월' 머리글 아래로 지난주 7칸이 그대로
  /// 남아, 화면이 스스로와 다른 기간을 말합니다.
  RecordPeriod? _shownPeriod;

  bool _loading = true;
  String? _error;

  /// 아이가 아직 없으면 기록 자체가 불가능합니다.
  bool _hasBaby = false;

  /// 조회가 한도에 걸려 기간의 일부만 읽었는지.
  ///
  /// 서비스들은 limit까지만 돌려주고 잘렸다는 말을 하지 않습니다. 그대로 두면
  /// "8월에 수유 400회"라고 적어 놓고 실제로는 최신 400건만 센 화면이 됩니다.
  /// 한도만큼 꽉 차서 왔으면 더 있을 수 있다고 봅니다.
  bool _truncated = false;

  /// 한 번이라도 읽어냈는지.
  ///
  /// 예전에는 `_records.isEmpty`로 판단했는데, 기간을 넘길 수 있게 되면서
  /// **기록이 없는 기간으로 갈 때마다 화면이 스피너로 갈아끼워졌습니다.**
  /// 그러면 높이가 0으로 줄어 스크롤이 맨 위로 튀고, 방금 누른 날짜가
  /// 사라졌다가 돌아옵니다.
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    final now = widget.clock();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _load();
    widget.refresh?.addListener(_onSignal);
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_onSignal);
    super.dispose();
  }

  /// 오늘을 따라가는 중인지. 지난 날을 직접 펴면 꺼지고, 다시 오늘을 고르면
  /// 켜집니다.
  ///
  /// 조회 시각으로 재지 않습니다. 조회는 신호 말고도 당겨서 새로고침·눈금
  /// 변경·'다시 시도'가 부르는데, 그중 하나가 자정을 넘겨 먼저 돌면 조회
  /// 시각만 새 날이 되어 **오늘을 보고 있던 사람이 어제에 갇혔습니다.**
  bool _followingToday = true;

  /// 신호를 받았을 때. 오늘을 보고 있었다면 새 오늘로 따라갑니다.
  ///
  /// [_selectedDay]는 initState에서 한 번만 정해집니다. [IndexedStack]이라
  /// 화면이 살아 있어 자정을 넘겨 돌아와도 어제에 머무는데, 그러면 방금 남긴
  /// 새벽 기록이 기간 밖으로 걸러져 '기록 없음'으로 보입니다 — 이 신호가
  /// 막으려던 바로 그 증상입니다.
  void _onSignal() {
    _selectedDay = dayAfterSignal(
      selectedDay: _selectedDay,
      followingToday: _followingToday,
      now: widget.clock(),
    );
    _load();
  }

  /// 이 조회가 몇 번째인지.
  ///
  /// 탭을 다시 누르거나 앱이 앞으로 나오면 [RefreshSignal]이 울리는데,
  /// 앞 조회가 끝났는지는 보지 않습니다. 그래서 두 조회가 겹칠 수 있고,
  /// **늦게 온 실패가 방금 성공한 결과를 덮었습니다** — 최신 목록을 손에
  /// 쥔 채 '불러오지 못했습니다'만 남고, 스스로 낫지도 않았습니다.
  ///
  /// 기간을 빠르게 넘길 때도 같은 일이 납니다. 지난달 응답이 늦게 도착해
  /// 이번 달 화면을 덮으면, 머리글과 원이 서로 다른 기간을 말합니다.
  ///
  /// 마지막 조회의 결과만 반영합니다.
  int _loadGen = 0;

  Future<void> _load() async {
    final gen = ++_loadGen;
    // 지금 조회하는 기간을 붙잡아 둡니다. 응답이 오는 사이에 눈금이나 날짜가
    // 바뀔 수 있는데, 그때 새 기간을 기준으로 원을 그리면 지난달 기록이
    // 이번 달 자리에 들어앉습니다.
    final period = _period;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loaded = await widget.loader(period);

      if (!mounted || gen != _loadGen) return;

      if (!loaded.hasBaby) {
        setState(() {
          _hasBaby = false;
          _records = const [];
          _patterns = const [];
          _shownPeriod = period;
          _truncated = false;
          _loadedOnce = true;
        });
        return;
      }

      // 합칠 때는 자르지 않습니다. 여기서 잘리면 기간 앞쪽 날들이 목록에서
      // 통째로 사라지는데, 원에는 그려져 있어 화면이 스스로와 어긋납니다.
      final total = loaded.feedings.length +
          loaded.diapers.length +
          loaded.sleeps.length +
          loaded.temperatures.length +
          loaded.growths.length +
          loaded.medications.length +
          loaded.visits.length;

      final merged = mergeRecentRecords(
        feedings: loaded.feedings,
        diapers: loaded.diapers,
        sleeps: loaded.sleeps,
        temperatures: loaded.temperatures,
        growths: loaded.growths,
        medications: loaded.medications,
        visits: loaded.visits,
        limit: total,
      );

      setState(() {
        _hasBaby = true;
        // 성공했으면 앞선 실패 표시를 지웁니다.
        _error = null;
        _truncated = loaded.truncated;
        // 하루 앞서 읽은 것과 성장(전체 조회)은 기간 밖이므로 걸러냅니다.
        _records = merged.where((r) => period.contains(r.at)).toList();
        _patterns = buildDayPatterns(
          period: period,
          feedings: loaded.feedings,
          diapers: loaded.diapers,
          sleeps: loaded.sleeps,
          // 아직 끝나지 않은 잠을 어디까지 그릴지 정합니다. 안 넘기면
          // 진짜 시계로 떨어져, 시계를 갈아 끼운 자리와 어긋납니다.
          now: widget.clock(),
        );
        _shownPeriod = period;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _error = '기록을 불러오지 못했습니다.');
      debugPrint('기록 조회 실패: $e');
    } finally {
      if (mounted && gen == _loadGen) setState(() => _loading = false);
    }
  }

  /// 눈금을 바꿉니다. **보던 날은 그대로 둡니다** — 지난달을 살펴보다 눈금을
  /// 바꾼 사람이 매번 오늘로 끌려오면 하던 일을 잃습니다.
  void _changeMode(PeriodMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _load();
  }

  /// 기간을 옮깁니다. 새 기간에 오늘이 있으면 오늘을, 없으면 첫날을 폅니다.
  ///
  /// 오늘이 없는 기간을 편 것은 지난(또는 앞선) 기간을 일부러 본다는 뜻이라
  /// 더는 오늘을 따라가지 않습니다.
  void _goTo(RecordPeriod period) {
    final now = widget.clock();
    setState(() {
      _followingToday = period.contains(now);
      _selectedDay = _followingToday
          ? DateTime(now.year, now.month, now.day)
          : period.start;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(title: '기록'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ..._buildBody(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    // 한 번이라도 읽어낸 뒤에는 스피너로 갈아끼우지 않습니다. 갈아끼우면
    // 화면 높이가 0으로 줄고, 되돌아올 때 스크롤이 맨 위로 튑니다
    // (RangeMaintainingScrollPhysics가 위치를 clamp합니다).
    if (_loading && !_loadedOnce) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    // 실패했더라도 손에 든 것이 있으면 그것부터 보여줍니다. 지우고 오류만
    // 남기면, 방금까지 보던 기록이 사라집니다.
    if (_error != null && !_loadedOnce) {
      return [
        Text(
          _error!,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        TextButton(onPressed: _load, child: const Text('다시 시도')),
      ];
    }

    // 낡았을 수 있다는 사실은 감추지 않습니다.
    //
    // 아이가 없다는 안내보다 **먼저** 만듭니다. 아이가 없는 상태에서 난
    // 조회 실패를 '아이 정보를 먼저 등록해 주세요' 한 줄로만 보여주면,
    // 실패한 조회가 화면 어디에도 남지 않고 다시 시도할 길도 없습니다.
    final stale = _error == null
        ? const <Widget>[]
        : [StaleNotice(message: _error!, onRetry: _load)];

    if (!_hasBaby) {
      return [
        ...stale,
        Text(
          '아이 정보를 먼저 등록해 주세요.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ];
    }

    final period = _period;

    // 손에 든 것이 다른 기간의 것이면 그리지 않습니다. 머리글은 이미 새
    // 기간을 가리키므로, 낡은 달력을 함께 두면 둘이 다른 말을 합니다.
    if (_shownPeriod != period) {
      return [
        // 여기서는 StaleNotice를 쓰지 않습니다. 그 문구는 '아래는 마지막으로
        // 읽은 내용입니다'인데, 새 기간의 기록은 한 건도 못 읽어 아래가
        // 비어 있습니다. 없는 것을 가리키는 안내는 그 자체로 거짓말입니다.
        if (_error != null) ...[
          Text(
            _error!,
            style:
                TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
          TextButton(onPressed: _load, child: const Text('다시 시도')),
        ],
        _buildModeToggle(),
        const SizedBox(height: AppSpacing.sm),
        _buildPeriodHeader(period),
        // 조회가 끝났는데도 기간이 어긋나 있다는 것은 실패했다는 뜻입니다.
        // 그때까지 스피너를 돌리면 끝난 조회를 '읽는 중'이라 말하게 되고,
        // 위의 StaleNotice가 가리키는 '마지막으로 읽은 내용'도 없습니다.
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    }

    final selected = _patternFor(_selectedDay);
    final ofDay = _records.where((r) => _isSameDay(r.at, _selectedDay)).toList();

    return [
      ...stale,
      if (_truncated) _buildTruncatedNotice(),
      _buildModeToggle(),
      const SizedBox(height: AppSpacing.sm),
      _buildPeriodHeader(period),
      const SizedBox(height: AppSpacing.sm),
      if (_mode == PeriodMode.week) _buildWeekStrip(),
      if (_mode == PeriodMode.month) _buildMonthCalendar(period),
      if (_mode != PeriodMode.day) const SizedBox(height: AppSpacing.lg),
      if (selected != null) _buildDayCard(selected),
      const SizedBox(height: AppSpacing.lg),
      // 하루 눈금에서는 머리글이 이미 그 날을 말했습니다.
      if (_mode != PeriodMode.day)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            formatDayHeader(_selectedDay),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ..._buildDayList(ofDay),
    ];
  }

  List<Widget> _buildDayList(List<RecentRecord> ofDay) {
    if (_records.isEmpty) {
      // 읽은 것은 이 기간뿐이므로 이 기간에 대해서만 말합니다. '아직 남긴
      // 기록이 없습니다'라고 적으면, 지난달까지 꾸준히 기록하다 이번 주를
      // 쉰 사람에게 한 번도 기록한 적 없다고 말하게 됩니다.
      return [
        Text(
          '이 기간에 남긴 기록이 없습니다.',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ];
    }

    if (ofDay.isEmpty) {
      return [
        Text(
          '이 날은 남긴 기록이 없습니다.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ];
    }

    return [for (final record in ofDay) _buildRow(record)];
  }

  DayPattern? _patternFor(DateTime day) {
    for (final p in _patterns) {
      if (_isSameDay(p.day, day)) return p;
    }
    return null;
  }

  /// 달력 날짜로 견줍니다. `difference().inDays`는 절대 시간을 재므로
  /// 서머타임이 낀 날에는 이웃한 두 날이 같은 값을 받습니다.
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildTruncatedNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '이 기간의 기록이 많아 일부만 불러왔습니다. '
              '더 짧은 눈금으로 보면 전부 보입니다.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 월 · 주 · 일. 왼쪽이 넓고 오른쪽이 좁습니다.
  Widget _buildModeToggle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.colors.primarySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in PeriodMode.values) _buildModeButton(mode),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(PeriodMode mode) {
    final active = mode == _mode;

    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        // 요일 라벨에도 '월'·'일'이 있어 글자만으로는 이 단추를 가리킬 수
        // 없습니다. 테스트가 눈금과 요일을 구별하는 데 씁니다.
        key: ValueKey('mode-${mode.name}'),
        onTap: () => _changeMode(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          // 높이를 박지 않습니다. 글씨를 키우면 그만큼 자라야 합니다.
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            mode.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              // 고른 쪽은 진한 초록 위 흰 글씨(대비 4.90:1)입니다.
              color: active ? Colors.white : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodHeader(RecordPeriod period) {
    // 앞으로는 넘어가지 못합니다. 아직 오지 않은 날의 빈 원들은 "기록을
    // 안 남겼다"와 구별되지 않습니다.
    //
    // '지금 기간인가'가 아니라 **끝난 기간인가**를 봅니다. 지금 기간만 막으면
    // 앞날의 기간에서는 이 단추가 살아나 끝없이 앞으로 갈 수 있습니다.
    final canGoNext = period.hasEnded(widget.clock());

    return Row(
      children: [
        IconButton(
          onPressed: () => _goTo(period.previous),
          icon: const Icon(Icons.chevron_left),
          color: context.colors.textSecondary,
          tooltip: '이전',
        ),
        Expanded(
          child: Text(
            period.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: canGoNext ? () => _goTo(period.next) : null,
          icon: const Icon(Icons.chevron_right),
          color: context.colors.textSecondary,
          tooltip: '다음',
        ),
      ],
    );
  }

  /// 요일 스트립. **격자가 아니라 줄입니다** — 이 화면에 격자를 두지 않는다는
  /// 원칙이 있고, 일곱 칸은 화면 너비에 맞춰 늘어나야 합니다.
  Widget _buildWeekStrip() {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          for (final pattern in _patterns)
            Expanded(child: _chip(pattern, _diameter(constraints.maxWidth))),
        ],
      ),
    );
  }

  /// 달 달력. 1일이 선 요일만큼 앞을 비우고 일곱 칸씩 줄을 바꿉니다.
  ///
  /// [GridView]를 쓰지 않습니다. 이 화면에는 기록하러 들어가는 격자를 두지
  /// 않는다는 원칙이 있고, 그것을 테스트가 `GridView`가 없음으로 지킵니다.
  /// 달력을 격자로 짜면 그 방어가 통째로 풀립니다.
  Widget _buildMonthCalendar(RecordPeriod period) {
    // DateTime.weekday는 월요일이 1이므로 그만큼 앞이 빕니다.
    final leading = period.start.weekday - 1;
    final cells = <DayPattern?>[
      for (var i = 0; i < leading; i++) null,
      ..._patterns,
    ];
    // 마지막 줄도 일곱 칸을 채워야 칸 너비가 위와 같아집니다.
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _diameter(constraints.maxWidth);

        return Column(
          children: [
            Row(
              children: [
                for (final label in const ['월', '화', '수', '목', '금', '토', '일'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < cells.length ~/ 7; row++)
              Row(
                children: [
                  for (final pattern in cells.sublist(row * 7, row * 7 + 7))
                    Expanded(
                      child: pattern == null
                          ? const SizedBox.shrink()
                          : _chip(pattern, size, showWeekday: false),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// 좁은 화면(320dp)에서도 일곱 개가 넘치지 않게 칸에 맞춰 줄입니다.
  double _diameter(double available) =>
      ((available / 7) - 6).clamp(24.0, 40.0).toDouble();

  Widget _chip(DayPattern pattern, double size, {bool showWeekday = true}) {
    return DayRingChip(
      pattern: pattern,
      size: size,
      showWeekday: showWeekday,
      selected: _isSameDay(pattern.day, _selectedDay),
      isToday: _isSameDay(pattern.day, widget.clock()),
      onTap: () => setState(() {
        _selectedDay = pattern.day;
        _followingToday = _isSameDay(pattern.day, widget.clock());
      }),
    );
  }

  Widget _buildDayCard(DayPattern pattern) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DayRing(pattern: pattern),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _legend(
                  const _Swatch(color: Colors.indigo, bar: true),
                  pattern.sleepArcs.isEmpty
                      ? '수면 기록 없음'
                      : '수면 ${formatDuration(pattern.sleepTotal)}'
                          '${pattern.hasOngoingSleep ? ' · 측정 중' : ''}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _legend(
                  const _Swatch(color: AppColors.primary),
                  '수유 ${pattern.feedingCount}회',
                ),
                const SizedBox(height: AppSpacing.sm),
                _legend(
                  const Text('💩', style: TextStyle(fontSize: 13)),
                  '배변 ${pattern.diaperCount}회',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Widget mark, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 14, child: Center(child: mark)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(RecentRecord record) {
    // 배변을 뺀 나머지는 홈 타일과 같은 아이콘·색을 씁니다. 다르면 같은
    // 기록이 화면마다 다른 것처럼 보입니다.
    final (icon, color) = switch (record.kind) {
      RecordKind.feeding => (Icons.baby_changing_station, AppColors.primary),
      RecordKind.diaper => (Icons.opacity, Colors.amber.shade700),
      RecordKind.sleep => (Icons.bedtime, Colors.indigo),
      RecordKind.temperature => (Icons.thermostat, Colors.red),
      RecordKind.growth => (Icons.show_chart, Colors.blue),
      RecordKind.medication => (Icons.medication_outlined, Colors.redAccent),
      RecordKind.hospital => (Icons.local_hospital_outlined, Colors.redAccent),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 배변만 그림 대신 이모지를 씁니다. 홈 타일은 물방울 아이콘을
          // 그대로 쓰므로 여기서만 다릅니다.
          SizedBox(
            width: 20,
            child: Center(
              child: record.kind == RecordKind.diaper
                  ? const Text('💩', style: TextStyle(fontSize: 16))
                  : Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.kind.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record.summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 성장은 잰 시각을 모릅니다(date 컬럼). '오전 12:00'을 붙이면
          // 자정에 쟀다는 뜻이 되므로 비웁니다.
          if (record.hasTime)
            Text(
              formatTimeOfDay(record.at),
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// 범례 앞에 붙는 표시. 수면은 원 위에서 호라서 막대로, 나머지는 점으로 씁니다.
class _Swatch extends StatelessWidget {
  final Color color;
  final bool bar;

  const _Swatch({required this.color, this.bar = false});

  @override
  Widget build(BuildContext context) => Container(
        width: bar ? 12 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(bar ? 2 : 4),
        ),
      );
}

/// 신호를 받았을 때 펴야 할 날.
///
/// 따라가는 중이면 새 오늘로 옮기고, 지난 날을 일부러 펴 둔 사람의 날은
/// 그대로 둡니다. **조회 시각을 보지 않습니다** — 자정 뒤에 당겨서 새로고침을
/// 하거나 '다시 시도'를 누르면 조회 시각만 새 날이 되어, 오늘을 보고 있던
/// 사람이 어제에 갇혔습니다.
@visibleForTesting
DateTime dayAfterSignal({
  required DateTime selectedDay,
  required bool followingToday,
  required DateTime now,
}) =>
    followingToday ? DateTime(now.year, now.month, now.day) : selectedDay;
