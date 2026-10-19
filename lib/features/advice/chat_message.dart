/// 대화 한 마디.
///
/// 서버는 대화를 저장하지 않습니다. 앱이 들고 있다가 매번 전부 보냅니다.
class ChatMessage {
  /// 서버가 받는 값과 같아야 합니다(`user` / `assistant`).
  final bool fromUser;

  final String text;

  /// 답변이 토큰 상한에 걸려 중간에 끊겼는지. 화면에서 그 사실을 밝힙니다.
  final bool truncated;

  const ChatMessage.user(this.text)
      : fromUser = true,
        truncated = false;
  const ChatMessage.assistant(this.text, {this.truncated = false})
      : fromUser = false;

  /// 서버로는 역할과 내용만 보냅니다. 끊겼다는 사실은 화면에서만 씁니다.
  Map<String, String> toJson() => {
        'role': fromUser ? 'user' : 'assistant',
        'content': text,
      };
}

/// 서버가 한 번에 받아 주는 최대 메시지 수.
///
/// 서버의 `MAX_CHAT_MESSAGES`와 같은 값이어야 합니다. 앱이 먼저 줄여
/// 보내지 않으면 서버가 413으로 거절합니다.
const int maxChatMessages = 40;

/// 오래된 말부터 잘라 [maxChatMessages] 이내로 맞춥니다.
///
/// 최근 대화가 더 중요하므로 앞쪽을 버립니다. 다만 첫 마디가 답변이 되면
/// 서버가 거절하므로, **보호자의 말부터 시작하도록** 맞춥니다.
List<ChatMessage> trimForRequest(List<ChatMessage> messages) {
  if (messages.length <= maxChatMessages) return messages;

  var trimmed = messages.sublist(messages.length - maxChatMessages);
  if (!trimmed.first.fromUser) trimmed = trimmed.sublist(1);
  return trimmed;
}
