import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../analysis/analysis_page.dart';
import '../community/community_page.dart';
import '../home/home_page.dart';
import '../records/records_page.dart';
import 'more_page.dart';

/// 하단 탭 5개를 담는 껍데기.
///
/// 각 탭은 자기 Scaffold(앱바·FAB)를 그대로 들고 있고, 이 화면은 하단 바만
/// 소유합니다. [IndexedStack]을 쓰므로 탭을 오갈 때 화면 상태가 유지됩니다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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
        children: const [
          HomePage(),
          RecordsPage(),
          AnalysisPage(),
          CommunityPage(),
          MorePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
    final color = active ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
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
