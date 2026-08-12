import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_app_bar.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../detail/assessment/assessment.dart';
import 'advice_service.dart';
import 'chat_context.dart';
import 'chat_message.dart';

/// 영역별 상담 대화.
///
/// 체온·수유·수면처럼 영역을 나눈 이유는, 같은 질문이라도 무엇에 대한
/// 이야기인지에 따라 답이 달라지기 때문입니다. 영역이 정해져 있으면
/// 보호자가 매번 "수유 얘긴데요"를 붙이지 않아도 됩니다.
///
/// 아이 정보와 최근 기록은 화면을 열 때 한 번 모아 두고 매 요청에 함께
/// 보냅니다. 대화 중에 다시 조회하지 않습니다 — 같은 대화 안에서 맥락이
/// 바뀌면 답변이 앞뒤로 어긋납니다.
class ChatPage extends StatefulWidget {
  final AssessmentDomain domain;

  /// 판정에서 바로 넘어온 경우 그 판정. 대화의 출발점이 됩니다.
  final Assessment? assessment;

  const ChatPage({super.key, required this.domain, this.assessment});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<ChatMessage> _messages = [];

  /// 아이 정보. 화면을 열 때 한 번 모읍니다.
  String? _context;
  bool _loadingContext = true;

  /// 맥락을 **못 만들었는지**. 아이가 없는 것과 다릅니다 — 못 만든 것을
  /// '미등록'으로 안내하면, 등록한 사람에게 등록하라고 말하게 됩니다.
  bool _contextFailed = false;

  bool _waiting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    // 기록을 못 읽어도 대화는 됩니다. 맥락 없이 일반적인 답이 올 뿐입니다.
    //
    // ChatContext가 안에서 예외를 삼키지만, 여기서도 한 번 더 막습니다.
    // 이 함수는 initState에서 await 없이 부르므로, 예외가 새어 나가면
    // 잡아 줄 곳이 없고 화면은 로딩 상태로 굳습니다.
    String context = '';
    var failed = false;
    try {
      context = await ChatContext.build(
        domain: widget.domain,
        assessment: widget.assessment,
      );
    } catch (e) {
      failed = true;
      debugPrint('상담 맥락을 만들지 못했습니다: $e');
    }

    if (!mounted) return;
    setState(() {
      _context = context;
      _contextFailed = failed;
      _loadingContext = false;
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _waiting) return;

    setState(() {
      _messages.add(ChatMessage.user(text));
      _input.clear();
      _waiting = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final advice = await AdviceService.ask(
        messages: _messages,
        domain: widget.domain,
        context: _context,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage.assistant(advice.answer, truncated: advice.truncated),
        );
        _waiting = false;
      });
    } on AdviceException catch (e) {
      if (!mounted) return;
      setState(() {
        // 실패한 질문은 대화에서 빼 둡니다. 남겨 두면 다시 보낼 때
        // 같은 말이 두 번 들어갑니다.
        _messages.removeLast();
        _input.text = text;
        _error = e.message;
        _waiting = false;
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    // 새 말이 그려진 뒤에 내려야 끝까지 갑니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(title: '${widget.domain.label} 상담'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty ? _buildIntro() : _buildMessages(),
            ),
            if (_error != null) _buildError(),
            // AI가 만든 문장을 보여주는 화면이라 상시 둡니다.
            // 문구는 앱이 한 곳에서 관리합니다(서버도 같은 취지의 문구를
            // 함께 내려주지만, 두 벌을 나란히 띄우면 시끄럽습니다).
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: MedicalDisclaimer(compact: true),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  /// 대화를 시작하기 전 화면.
  ///
  /// 빈 화면에 입력칸만 두면 무엇을 물어야 할지 막막합니다. 그 영역에서
  /// 흔히 묻는 것을 눌러 바로 시작할 수 있게 합니다.
  Widget _buildIntro() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          '${widget.domain.label}에 대해\n편하게 물어봐 주세요',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.4,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _loadingContext
              ? '아이 기록을 불러오는 중이에요…'
              : _contextFailed
                  ? '기록을 불러오지 못해 일반적인 내용으로 답해 드려요.'
                  : _context == null || _context!.isEmpty
                      ? '아이 정보를 등록하면 기록을 함께 보고 답해 드려요.'
                      : '아이의 개월 수와 최근 기록을 함께 보고 답해 드려요.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        for (final q in _suggestionsFor(widget.domain))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _suggestion(q),
          ),
      ],
    );
  }

  Widget _suggestion(String question) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // 맥락을 아직 모으는 중이면 잠급니다. 지금 보내면 첫 질문만 맥락
        // 없이 나가는데, 대화의 출발점이라 그게 가장 아쉬운 자리입니다.
        onTap: (_waiting || _loadingContext) ? null : () => _send(question),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            question,
            style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _messages.length + (_waiting ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _buildTyping();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(ChatMessage message) {
    final mine = message.fromUser;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // 화면 폭을 다 채우면 누가 한 말인지 한눈에 안 보입니다.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mine ? AppColors.primary.withValues(alpha: 0.3) : context.colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: context.colors.textPrimary,
              ),
            ),
            // 끊긴 답을 완성된 답인 것처럼 두면 잘린 문장을 결론으로 읽습니다.
            if (message.truncated) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_horiz,
                    size: 15,
                    color: context.colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '답변이 길어 여기서 끊겼어요. 나눠서 다시 물어봐 주세요.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '답변을 쓰는 중이에요…',
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              // 서버의 max_question_chars와 같은 값입니다.
              maxLength: 500,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: '궁금한 점을 적어 주세요',
                counterText: '',
                filled: true,
                fillColor: context.colors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _waiting ? null : _send,
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.arrow_upward, size: 20),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// 영역마다 흔히 묻는 것.
///
/// 빈 입력칸만 두면 무엇을 물어야 할지 막막합니다. 눌러서 바로 시작할 수
/// 있게 두되, 답을 미리 정해 두지는 않습니다 — 질문만 대신 적어 줍니다.
List<String> _suggestionsFor(AssessmentDomain domain) {
  switch (domain) {
    case AssessmentDomain.temperature:
      return [
        '열이 나는데 지금 병원에 가야 할까요?',
        '해열제를 먹여도 열이 안 내려요',
        '열이 날 때 집에서 어떻게 해 주면 좋을까요?',
      ];
    case AssessmentDomain.feeding:
      return [
        '먹는 양이 줄었는데 괜찮을까요?',
        '수유 간격이 어느 정도가 좋을까요?',
        '먹고 나서 자꾸 토해요',
      ];
    case AssessmentDomain.sleep:
      return [
        '밤에 자꾸 깨는데 어떻게 해야 할까요?',
        '낮잠을 얼마나 재우면 좋을까요?',
        '잠들기까지 너무 오래 걸려요',
      ];
    case AssessmentDomain.diaper:
      return [
        '변이 평소와 달라요',
        '며칠째 응가를 안 해요',
        '소변 횟수가 줄었는데 괜찮을까요?',
      ];
    case AssessmentDomain.growth:
      return [
        '또래보다 작은 것 같아 걱정돼요',
        '몸무게가 잘 안 늘어요',
        '성장 곡선은 어떻게 보는 건가요?',
      ];
    case AssessmentDomain.noise:
      return [
        '아이 방이 시끄러운데 어떻게 줄일까요?',
        '백색소음을 틀어 줘도 괜찮을까요?',
        '소음이 수면에 얼마나 영향을 주나요?',
      ];
    case AssessmentDomain.skin:
      return [
        '피부가 붉게 올라왔어요',
        '아기 피부는 어떻게 관리하면 좋을까요?',
        '보습제를 얼마나 자주 발라 줘야 하나요?',
      ];
    case AssessmentDomain.overall:
      return [
        '아이가 평소와 달라 보여요',
        '병원에 가야 할지 판단이 안 서요',
        '예방접종 전에 확인할 것이 있을까요?',
      ];
  }
}
