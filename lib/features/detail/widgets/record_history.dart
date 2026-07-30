import 'package:flutter/material.dart';

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

  static const Color _textColor = Color(0xFF1F2937);
  static const Color _secondaryTextColor = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textColor,
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
                  style: const TextStyle(color: _secondaryTextColor, fontSize: 13),
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
              style: const TextStyle(color: _secondaryTextColor, fontSize: 13),
            ),
          )
        else
          ...entries.map(_buildTile),
      ],
    );
  }

  Widget _buildTile(RecordHistoryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: _secondaryTextColor),
              onPressed: () => onDelete!(entry.id),
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
