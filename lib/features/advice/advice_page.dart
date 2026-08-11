import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/widgets/common_app_bar.dart';
import '../detail/assessment/assessment.dart';
import 'advice_service.dart';

/// 육아 질문 화면.
///
/// 판정 결과 화면에서 "이게 무슨 뜻인가요?"라고 이어 물을 수 있도록,
/// [domain]과 [context]를 받아 그대로 서버에 넘깁니다.
class AdvicePage extends StatefulWidget {
  /// 어느 영역에 대한 질문인지. 서버가 프롬프트에 넣습니다.
  final AssessmentDomain domain;

  /// 아이 개월 수와 최근 기록 요약. [buildAdviceContext]로 만듭니다.
  final String? context;

  const AdvicePage({
    super.key,
    this.domain = AssessmentDomain.overall,
    this.context,
  });

  @override
  State<AdvicePage> createState() => _AdvicePageState();
}

class _AdvicePageState extends State<AdvicePage> {
  final _controller = TextEditingController();

  Advice? _advice;
  bool _loading = false;
  String? _error;

  /// 방금 무엇을 물었는지. 답변 위에 함께 보여줍니다.
  String? _askedQuestion;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.length < 2) {
      setState(() => _error = '질문을 조금 더 자세히 적어 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _advice = null;
      _askedQuestion = question;
    });

    try {
      final advice = await AdviceService.ask(
        question: question,
        domain: widget.domain,
        context: widget.context,
      );
      if (!mounted) return;
      setState(() => _advice = advice);
    } on AdviceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: CommonAppBar(title: '${widget.domain.label} 질문하기'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildInput(),
          const SizedBox(height: AppSpacing.lg),
          if (_loading) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(
                '답변을 만들고 있어요…',
                style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
              ),
            ),
          ],
          if (_error != null) _buildError(_error!),
          if (_advice != null) _buildAnswer(_advice!),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.domain.label}에 대해 궁금한 점을 적어 주세요',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: TextField(
            controller: _controller,
            maxLines: 4,
            // 서버도 500자에서 막지만, 여기서 먼저 알려주는 편이 낫습니다.
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: '예: 밤에 자주 깨는데 괜찮을까요?',
              contentPadding: EdgeInsets.all(AppSpacing.lg),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _ask,
            child: const Text('물어보기'),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswer(Advice advice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_askedQuestion != null) ...[
          Text(
            'Q. $_askedQuestion',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            advice.answer,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 서버가 내려준 고지를 그대로 보여줍니다. 앱이 다시 쓰지 않는 이유는
        // 문구가 두 곳에서 갈라지지 않게 하기 위해서입니다.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  advice.disclaimer,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
