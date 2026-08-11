import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../detail/assessment/assessment.dart';
import 'chat_page.dart';

/// 어느 영역에 대해 물을지 고르는 화면.
///
/// 기록 화면을 거치지 않고 **바로 물을 수 있는 길**입니다. 새벽에 아이가
/// 열이 나면 체온을 기록할 겨를도 없이 먼저 묻고 싶습니다.
class ChatHomePage extends StatelessWidget {
  const ChatHomePage({super.key});

  /// 상담할 수 있는 영역과 아이콘.
  ///
  /// `overall`을 맨 위에 둡니다 — 무엇에 대한 질문인지 스스로도 모를 때가
  /// 많고, 그때 고를 곳이 없으면 화면을 닫게 됩니다.
  static const List<({AssessmentDomain domain, IconData icon, String hint})>
      _topics = [
    (
      domain: AssessmentDomain.overall,
      icon: Icons.help_outline,
      hint: '무엇부터 물어야 할지 모를 때'
    ),
    (
      domain: AssessmentDomain.temperature,
      icon: Icons.thermostat,
      hint: '열이 날 때, 병원에 가야 할지'
    ),
    (
      domain: AssessmentDomain.feeding,
      icon: Icons.baby_changing_station,
      hint: '먹는 양, 수유 간격, 토할 때'
    ),
    (
      domain: AssessmentDomain.sleep,
      icon: Icons.bedtime,
      hint: '밤에 깰 때, 낮잠, 잠투정'
    ),
    (
      domain: AssessmentDomain.diaper,
      icon: Icons.opacity,
      hint: '변 색깔과 굳기, 횟수'
    ),
    (
      domain: AssessmentDomain.growth,
      icon: Icons.show_chart,
      hint: '키와 몸무게, 또래와 비교'
    ),
    (
      domain: AssessmentDomain.skin,
      icon: Icons.face_retouching_natural,
      hint: '발진, 건조함, 보습'
    ),
    (
      domain: AssessmentDomain.noise,
      icon: Icons.volume_up_outlined,
      hint: '잠자는 환경, 백색소음'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: const CommonAppBar(title: '상담'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '어떤 것이 궁금하세요?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아이의 개월 수와 최근 기록을 함께 보고 답해 드려요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          for (final t in _topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _topicTile(context, t.domain, t.icon, t.hint),
            ),
          const SizedBox(height: 12),
          const MedicalDisclaimer(),
        ],
      ),
    );
  }

  Widget _topicTile(
    BuildContext context,
    AssessmentDomain domain,
    IconData icon,
    String hint,
  ) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatPage(domain: domain)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      domain.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: context.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
