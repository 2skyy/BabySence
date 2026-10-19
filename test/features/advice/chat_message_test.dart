import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_project/features/advice/chat_message.dart';

/// 대화를 서버로 보내기 전에 다듬는 규칙을 고정합니다.
///
/// 서버는 대화를 저장하지 않습니다. 앱이 매번 전부 보내므로, 길이를 앱이
/// 먼저 줄이지 않으면 서버가 413으로 거절합니다.
void main() {
  List<ChatMessage> conversation(int turns) => [
        for (var i = 0; i < turns; i++)
          i.isEven ? ChatMessage.user('질문 $i') : ChatMessage.assistant('답변 $i'),
      ];

  test('서버가 받는 형식으로 바꾼다', () {
    expect(const ChatMessage.user('안녕하세요').toJson(),
        {'role': 'user', 'content': '안녕하세요'});
    expect(const ChatMessage.assistant('네, 안녕하세요').toJson(),
        {'role': 'assistant', 'content': '네, 안녕하세요'});
  });

  test('짧은 대화는 그대로 보낸다', () {
    final messages = conversation(6);
    expect(trimForRequest(messages), same(messages));
  });

  test('상한을 넘으면 오래된 것부터 자른다', () {
    // 최근 대화가 더 중요합니다.
    final trimmed = trimForRequest(conversation(maxChatMessages + 10));

    expect(trimmed.length, lessThanOrEqualTo(maxChatMessages));
    expect(trimmed.last.text, endsWith('${maxChatMessages + 9}'));
  });

  test('자른 뒤에도 보호자의 말로 시작한다', () {
    // 답변으로 시작하면 서버가 거절합니다. 자르는 위치가 홀수일 때
    // 한 마디를 더 버려야 합니다.
    for (var extra = 1; extra <= 6; extra++) {
      final trimmed = trimForRequest(conversation(maxChatMessages + extra));

      expect(trimmed.first.fromUser, isTrue, reason: '$extra개 초과일 때');
      expect(trimmed.length, lessThanOrEqualTo(maxChatMessages));
    }
  });

  test('마지막은 언제나 보호자의 말이다', () {
    // 대화는 항상 질문으로 끝난 상태에서 보냅니다.
    final trimmed = trimForRequest(conversation(maxChatMessages + 5));
    expect(trimmed.last.fromUser, isTrue);
  });
}
