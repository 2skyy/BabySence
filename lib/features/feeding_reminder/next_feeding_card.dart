import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'feeding_reminder_service.dart';
import 'feeding_reminder_settings.dart';
import 'feeding_schedule.dart';

/// 홈 맨 위의 '다음 수유' 카드.
///
/// 예전에는 이 자리에 오늘 기록 요약이 있었습니다. 지난 것을 보여주는 것보다
/// 앞으로 할 것을 보여주는 편이 홈에서 쓸모가 큽니다.
///
/// **앱이 간격을 추측하지 않습니다.** 보호자가 정하기 전에는 다음 시각을
/// 계산하지 않고 정해 달라고만 합니다 — 임의의 값을 채워 넣으면 그 숫자가
/// 근거처럼 읽힙니다.
class NextFeedingCard extends StatefulWidget {
  /// 마지막 수유 시각. 기록이 없으면 null입니다.
  final DateTime? lastFedAt;

  /// 간격을 처음 정할 때 미리 넣어 둘 값을 고르는 데 씁니다.
  final int? ageInMonths;

  /// 기록이 아직 오는 중인지.
  final bool loading;

  /// 기록을 **못 읽었는지**. 값이 없는 것과 다릅니다.
  ///
  /// 예전에는 홈이 조회에 실패하면 [lastFedAt]이 그냥 null로 왔습니다. 그러면
  /// 이 위젯이 "수유를 기록해 주세요"를 띄우고 **예약된 알림까지 취소**했습니다
  /// (reschedule이 cancel부터 하고 nextAt이 null이라 그대로 끝납니다).
  /// 통신 없는 곳에서 앱을 한 번 열면 그날 알림을 놓쳤습니다.
  final bool failed;

  const NextFeedingCard({
    super.key,
    required this.lastFedAt,
    this.ageInMonths,
    this.loading = false,
    this.failed = false,
  });

  @override
  State<NextFeedingCard> createState() => _NextFeedingCardState();
}

class _NextFeedingCardState extends State<NextFeedingCard> {
  FeedingReminderSettings _settings = FeedingReminderSettings.none;
  bool _loadingSettings = true;

  /// 남은 시간을 1분마다 다시 그립니다. 안 하면 '3분 뒤'가 한참 지나도
  /// 그대로 붙어 있습니다.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(NextFeedingCard old) {
    super.didUpdateWidget(old);
    // 수유를 기록하고 돌아오면 마지막 시각이 바뀝니다. 알림도 다시 잡습니다.
    // 설정은 그대로이므로 저장까지 하지는 않습니다.
    if (old.lastFedAt != widget.lastFedAt ||
        old.loading != widget.loading ||
        old.failed != widget.failed) {
      _rescheduleIfKnown(_settings);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await FeedingReminderSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loadingSettings = false;
    });
    _rescheduleIfKnown(settings);
  }

  /// 기록을 제대로 읽었을 때만 알림을 다시 잡습니다.
  ///
  /// 모르는 상태(로딩·실패)에서 부르면 예약을 지우기만 합니다.
  void _rescheduleIfKnown(FeedingReminderSettings settings) {
    if (widget.loading || widget.failed) return;
    FeedingReminderService.reschedule(_schedule(settings),
        notify: settings.notify);
  }

  FeedingSchedule _schedule(FeedingReminderSettings settings) =>
      FeedingSchedule(lastFedAt: widget.lastFedAt, interval: settings.interval);

  Future<void> _apply(FeedingReminderSettings settings) async {
    if (mounted) setState(() => _settings = settings);
    await settings.save();
    _rescheduleIfKnown(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '다음 수유',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (_settings.isConfigured)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '수유 알림 설정',
                  onPressed: _openSettings,
                  icon: Icon(
                    _settings.notify
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildBody(),
        ],
      ),
    );
  }

  List<Widget> _buildBody() {
    if (widget.loading || _loadingSettings) {
      return [_headline('불러오는 중이에요'), const SizedBox(height: 8), _detail('')];
    }

    // 못 읽은 것을 "기록해 주세요"로 바꿔 말하지 않습니다. 예약도 건드리지
    // 않았으므로 이미 잡힌 알림은 그대로 옵니다.
    if (widget.failed) {
      return [
        _headline('불러오지 못했어요'),
        const SizedBox(height: 8),
        _detail('기록을 읽지 못해 다음 시각을 셀 수 없어요. '
            '이미 예약된 알림은 그대로 옵니다.'),
      ];
    }

    // 아직 간격을 정하지 않음 — 앱이 대신 정하지 않습니다.
    if (!_settings.isConfigured) {
      return [
        _headline('수유 간격을 정해 주세요'),
        const SizedBox(height: 8),
        _detail('정하시면 다음 수유 시각을 알려드릴게요. 아이마다 달라 앱이 대신 정하지 않습니다.'),
        const SizedBox(height: 14),
        FilledButton.tonal(
          onPressed: _openSettings,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.primary,
          ),
          child: const Text('간격 정하기'),
        ),
      ];
    }

    final schedule = _schedule(_settings);
    final next = schedule.nextAt;

    if (next == null) {
      return [
        _headline('수유를 기록해 주세요'),
        const SizedBox(height: 8),
        _detail(
          '마지막 수유 기록이 있어야 다음 시각을 셀 수 있어요. '
          '간격은 ${formatInterval(_settings.interval!)}로 정해 두셨어요.',
        ),
      ];
    }

    final now = DateTime.now();
    final overdue = schedule.isOverdueAt(now);

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          _headline(formatClock(next)),
          const SizedBox(width: 10),
          Text(
            formatRemaining(schedule.remainingAt(now)!),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: overdue ? AppColors.error : AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _detail(
              '마지막 수유 ${formatClock(widget.lastFedAt!)}'
              ' · 간격 ${formatInterval(_settings.interval!)}',
            ),
          ),
          Icon(
            overdue ? Icons.notifications_active : Icons.schedule,
            color: overdue ? AppColors.error : AppColors.primary,
            size: 30,
          ),
        ],
      ),
    ];
  }

  Widget _headline(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: context.colors.textPrimary,
        ),
      );

  Widget _detail(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: context.colors.textSecondary,
        ),
      );

  Future<void> _openSettings() async {
    final picked = await showModalBottomSheet<FeedingReminderSettings>(
      context: context,
      backgroundColor: context.colors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(
        settings: _settings,
        suggested: suggestedInterval(widget.ageInMonths ?? 0),
      ),
    );

    if (picked != null) await _apply(picked);
  }
}

/// 간격과 알림 켬/끔을 고르는 시트.
class _SettingsSheet extends StatefulWidget {
  final FeedingReminderSettings settings;

  /// 아직 정한 값이 없을 때 미리 골라 둘 값.
  final Duration suggested;

  const _SettingsSheet({required this.settings, required this.suggested});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late Duration _interval = widget.settings.interval ?? widget.suggested;
  late bool _notify = widget.settings.notify;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '수유 알림',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '마지막 수유에서 이만큼 지나면 알려드려요.\n'
              '아이마다 달라서 정해진 값은 없습니다 — 편하신 대로 맞춰 주세요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in selectableIntervals)
                  ChoiceChip(
                    label: Text(formatInterval(option)),
                    selected: option == _interval,
                    onSelected: (_) => setState(() => _interval = option),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              title: Text(
                '알림 받기',
                style: TextStyle(
                  fontSize: 15,
                  color: context.colors.textPrimary,
                ),
              ),
              subtitle: Text(
                _notify ? '시간이 되면 알림이 옵니다' : '홈에서 다음 시각만 보여드립니다',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  FeedingReminderSettings(interval: _interval, notify: _notify),
                ),
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
