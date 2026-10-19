import 'package:flutter/material.dart';

/// 되돌릴 수 없는 일을 하기 전에 한 번 묻습니다.
///
/// 커뮤니티 글·댓글 삭제에만 있던 것을 옮겨 왔습니다. 기록 삭제는 확인 없이
/// 곧바로 지웠는데, 이 앱의 기록은 **다시 만들 수 없습니다** — 한 시간을 잰
/// 수면도, 새벽에 적은 체온도, 목록에서 휴지통을 한 번 잘못 누르면 끝이었고
/// 실행 취소 수단이 앱 어디에도 없습니다.
///
/// 반환값이 `true`일 때만 진행하세요. 바깥을 눌러 닫으면 `null`입니다.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = '삭제',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
