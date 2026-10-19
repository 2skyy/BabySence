import 'package:flutter/material.dart';

import '../../../core/widgets/confirm_dialog.dart';

import '../../../core/constants/app_colors.dart';

/// 기록 이력 목록의 한 줄.
class RecordHistoryEntry {
  /// 삭제에 사용할 행 id.
  final String id;

  /// 첫 줄. 보통 시각입니다.
  final String title;

  /// 둘째 줄. 기록 내용입니다.
  final String subtitle;

  const RecordHistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

/// 기록 화면 아래에 붙는 이력 목록.
///
/// 수유·배변·수면·체온 네 화면이 같은 모양을 쓰므로 한 곳에 모았습니다.
/// 성장 기록 화면의 이력 목록과 같은 구성입니다.
class RecordHistorySection extends StatelessWidget {
  final String title;
  final bool loading;
  final String? error;
  final List<RecordHistoryEntry> entries;

  /// 오류 후 다시 시도. null이면 버튼을 숨깁니다.
  final Future<void> Function()? onRetry;

  /// 한 줄을 삭제. null이면 삭제 버튼을 숨깁니다.
  final Future<void> Function(String id)? onDelete;

  /// 비어 있을 때 보여줄 문구.
  final String emptyText;

  const RecordHistorySection({
    super.key,
    required this.title,
    required this.entries,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onDelete,
    this.emptyText = '아직 기록이 없습니다.',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error!,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: () => onRetry!(),
                    child: const Text('다시 시도'),
                  ),
              ],
            ),
          )
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              emptyText,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
          )
        else
          ...entries.map((e) => _buildTile(context, e)),
      ],
    );
  }

  Widget _buildTile(BuildContext context, RecordHistoryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.colors.textSecondary),
              // **한 번 묻고 지웁니다.** 이 목록의 기록은 다시 만들 수
              // 없습니다. 예전에는 곧바로 지웠고, 실행 취소 수단이 앱
              // 어디에도 없었습니다. 확인 창을 여기 한 곳에 두면 이 위젯을
              // 쓰는 다섯 화면(체온·수유·수면·배변·약/병원)이 함께 덮입니다.
              onPressed: () async {
                final ok = await confirmDestructive(
                  context,
                  title: '이 기록을 지울까요?',
                  body: '${entry.title}\n${entry.subtitle}\n\n지운 기록은 되돌릴 수 없습니다.',
                );
                if (ok) await onDelete!(entry.id);
              },
            ),
        ],
      ),
    );
  }
}

/// 이력 목록의 시각 표기를 한 곳에서 만듭니다.
///
/// 오늘이면 시각만, 그 외에는 날짜까지 보여줍니다.
String formatRecordTime(DateTime at, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final isToday = at.year == reference.year &&
      at.month == reference.month &&
      at.day == reference.day;

  final hour = at.hour;
  final period = hour < 12 ? '오전' : '오후';
  // 0시는 오전 12시, 13시는 오후 1시로 표기합니다.
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final time = '$period $hour12:${at.minute.toString().padLeft(2, '0')}';

  if (isToday) return '오늘 $time';
  return '${at.month}/${at.day} $time';
}
