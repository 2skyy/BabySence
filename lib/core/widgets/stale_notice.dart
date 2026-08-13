import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// 손에 든 값은 그대로 두고 "지금 것이 아닐 수 있다"만 얹습니다.
///
/// 실패했다고 보던 목록을 지우면 방금까지 있던 기록이 사라집니다.
/// 그렇다고 실패를 감추면 낡은 값을 최신인 줄 알고 봅니다.
class StaleNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const StaleNotice({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$message 아래는 마지막으로 읽은 내용입니다.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
