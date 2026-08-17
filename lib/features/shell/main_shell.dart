import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/refresh_signal.dart';
import '../analysis/analysis_page.dart';
import '../community/community_page.dart';
import '../home/home_page.dart';
import '../records/records_page.dart';
import 'more_page.dart';

/// 하단 탭 5개를 담는 껍데기.
///
/// 각 탭은 자기 Scaffold(앱바·FAB)를 그대로 들고 있고, 이 화면은 하단 바만
/// 소유합니다. [IndexedStack]을 쓰므로 탭을 오갈 때 화면 상태가 유지됩니다.
///
/// 상태가 유지되는 대신 **다시 읽을 계기가 없습니다.** 그래서 탭을 고를 때와
/// 앱이 다시 앞으로 나올 때 그 탭에만 [RefreshSignal]을 울립니다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  /// 탭마다 하나씩. 보이는 탭에만 울립니다.
  final _home = RefreshSignal();
  final _records = RefreshSignal();
  final _analysis = RefreshSignal();

  @override
  void initState() {
    super.initState();
    // 앱이 다시 앞으로 나올 때를 알려면 필요합니다. 자정을 넘긴 뒤
    // 돌아오는 경우가 여기 걸립니다.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _home.dispose();
    _records.dispose();
    _analysis.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 보이는 탭만 다시 읽습니다.
    if (state == AppLifecycleState.resumed) _signalFor(_index)?.fire();
  }

  RefreshSignal? _signalFor(int index) => switch (index) {
        0 => _home,
        1 => _records,
        2 => _analysis,
        _ => null,
      };

  void _select(int index) {
    setState(() => _index = index);
    // 이미 보고 있던 탭을 다시 눌러도 새로고침이 됩니다.
    _signalFor(index)?.fire();
  }

  static const _tabs = <_Tab>[
    _Tab(Icons.home_outlined, Icons.home, '홈'),
    _Tab(Icons.edit_note_outlined, Icons.edit_note, '기록'),
    _Tab(Icons.bar_chart_outlined, Icons.bar_chart, '분석'),
    _Tab(Icons.forum_outlined, Icons.forum, '커뮤니티'),
    _Tab(Icons.menu, Icons.menu, '전체'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(refresh: _home),
          RecordsPage(refresh: _records),
          AnalysisPage(refresh: _analysis),
          const CommunityPage(),
          const MorePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _tabs.length; i++) _buildItem(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int i) {
    final tab = _tabs[i];
    final active = i == _index;
    final color = active ? AppColors.primary : context.colors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => _select(i),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? tab.activeIcon : tab.icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _Tab(this.icon, this.activeIcon, this.label);
}
