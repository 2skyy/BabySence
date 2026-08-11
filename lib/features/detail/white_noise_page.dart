import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
// 방금 만든 백색소음 서비스 import (경로에 맞게 수정해 주세요)
import 'white_noise_service.dart';

class WhiteNoiseItem {
  final String id;
  final String title;
  final String assetPath;
  final IconData icon;

  WhiteNoiseItem({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.icon,
  });
}

class WhiteNoisePage extends StatefulWidget {
  const WhiteNoisePage({super.key});

  @override
  State<WhiteNoisePage> createState() => _WhiteNoisePageState();
}

class _WhiteNoisePageState extends State<WhiteNoisePage> {
  // 싱글톤 서비스 가져오기
  final WhiteNoiseService _noiseService = WhiteNoiseService();

  final List<WhiteNoiseItem> _noiseList = [
    WhiteNoiseItem(
      id: 'womb',
      title: '포근한 심장소리',
      assetPath: 'audio/womb.mp3',
      icon: Icons.child_care_rounded,
    ),
    WhiteNoiseItem(
      id: 'dryer',
      title: '헤어드라이기',
      assetPath: 'audio/dryer.mp3',
      icon: Icons.mode_fan_off_rounded,
    ),
    WhiteNoiseItem(
      id: 'cutting',
      title: '도마/가위 소리',
      assetPath: 'audio/cutting.mp3',
      icon: Icons.content_cut_rounded,
    ),
    WhiteNoiseItem(
      id: 'waves',
      title: '잔잔한 파도소리',
      assetPath: 'audio/waves.mp3',
      icon: Icons.waves_rounded,
    ),
    WhiteNoiseItem(
      id: 'fire',
      title: '따뜻한 장작소리',
      assetPath: 'audio/fire.mp3',
      icon: Icons.local_fire_department_rounded,
    ),
    WhiteNoiseItem(
      id: 'whitenoise',
      title: '클래식 백색소음',
      assetPath: 'audio/whitenoise.mp3',
      icon: Icons.graphic_eq_rounded,
    ),
    WhiteNoiseItem(
      id: 'rain',
      title: '포근한 빗소리',
      assetPath: 'audio/rain.mp3',
      icon: Icons.water_drop_rounded,
    ),
    WhiteNoiseItem(
      id: 'nature',
      title: '평화로운 자연소리',
      assetPath: 'audio/nature.mp3',
      icon: Icons.park_rounded,
    ),
    WhiteNoiseItem(
      id: 'shush',
      title: '쉬~ 달래는 소리',
      assetPath: 'audio/shush.mp3',
      icon: Icons.volume_down_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text(
          '아기 안심 백색소음',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: context.colors.surface,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: _noiseList.length,
              itemBuilder: (context, index) {
                final item = _noiseList[index];
                final isSelected = _noiseService.currentPlayingId == item.id && _noiseService.isPlaying;

                return GestureDetector(
                  onTap: () {
                    _noiseService.togglePlay(
                      id: item.id,
                      assetPath: item.assetPath,
                      onStateChanged: () => setState(() {}),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? Icons.pause_circle_filled_rounded : item.icon,
                          size: 32,
                          color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade700,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item.title,
                            textAlign: TextAlign.center,
                            // 3열이라 칸이 좁습니다. 긴 이름은 두 줄까지만 씁니다.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF1A73E8) : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_noiseService.currentPlayingId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _noiseService.isPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: const Color(0xFF1A73E8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _noiseService.isPlaying
                          ? '${_noiseList.firstWhere((e) => e.id == _noiseService.currentPlayingId).title} 재생 중...'
                          : '일시 정지됨',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final currentItem = _noiseList.firstWhere((e) => e.id == _noiseService.currentPlayingId);
                      _noiseService.togglePlay(
                        id: currentItem.id,
                        assetPath: currentItem.assetPath,
                        onStateChanged: () => setState(() {}),
                      );
                    },
                    icon: Icon(_noiseService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    color: const Color(0xFF1A73E8),
                  ),
                  IconButton(
                    onPressed: () {
                      _noiseService.stopAll(() => setState(() {}));
                    },
                    icon: const Icon(Icons.stop_rounded),
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}