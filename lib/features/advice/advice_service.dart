import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import '../detail/assessment/assessment.dart';

/// 서버가 돌려준 답변.
class Advice {
  final String answer;

  /// 서버가 붙이는 고정 고지 문구. 모델이 쓰지 않습니다.
  final String disclaimer;

  const Advice({required this.answer, required this.disclaimer});
}

/// 육아 질문에 대한 답변을 받아옵니다.
///
/// **Claude를 앱에서 직접 부르지 않습니다.** API 키를 앱에 넣으면 패키지를
/// 뜯어 꺼낼 수 있습니다. 키는 FastAPI 서버의 환경변수에만 있습니다.
class AdviceService {
  static final Dio _dio = Dio(
    BaseOptions(
      // 답변은 몇 초 걸립니다. 기본값(무제한)이면 서버가 죽었을 때
      // 화면이 영영 도는 중으로 남습니다.
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// 서버에 질문하고 답변을 받습니다.
  ///
  /// [context]는 앱이 조립합니다 — 서버는 DB에 붙지 않아 기록을 직접
  /// 조회할 수 없습니다. 아이 이름 같은 식별 정보는 넣지 마세요.
  static Future<Advice> ask({
    required String question,
    required AssessmentDomain domain,
    String? context,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.advice,
        data: {
          'question': question,
          // enum 이름이 서버의 DOMAINS 키와 같습니다.
          'domain': domain.name,
          if (context != null && context.isNotEmpty) 'context': context,
        },
      );

      final data = response.data as Map;
      return Advice(
        answer: data['answer'] as String,
        disclaimer: data['disclaimer'] as String,
      );
    } on DioException catch (e) {
      throw AdviceException(_messageFor(e));
    }
  }

  /// 서버가 상황별 한국어 문구를 내려주므로 그대로 씁니다.
  /// 그 밖의 경우만 앱에서 문구를 만듭니다.
  static String _messageFor(DioException e) {
    final detail = (e.response?.data is Map)
        ? (e.response!.data as Map)['detail']
        : null;
    if (detail is String && detail.isNotEmpty) return detail;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return '답변 서버에 연결하지 못했습니다. 서버가 켜져 있는지 확인해 주세요.';
      case DioExceptionType.receiveTimeout:
        return '답변이 오지 않았습니다. 잠시 후 다시 시도해 주세요.';
      default:
        return '답변을 받지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}

class AdviceException implements Exception {
  final String message;
  const AdviceException(this.message);

  @override
  String toString() => message;
}

/// 아이 정보와 최근 기록을 모델이 읽을 맥락 문장으로 만듭니다.
///
/// 이름이나 아이디는 넣지 않습니다. 답변에 필요하지도 않고, 외부 서비스로
/// 나가는 개인정보를 줄이려는 것입니다.
String buildAdviceContext({
  int? ageInMonths,
  Assessment? assessment,
  List<String> recentRecords = const [],
}) {
  final lines = <String>[];

  if (ageInMonths != null) {
    lines.add('- 생후 $ageInMonths개월');
  }

  if (assessment != null) {
    lines.add(
      '- 앱 판정: ${assessment.domain.label} ${assessment.level.label}'
      ' (기준 버전 ${assessment.ruleVersion})',
    );
    lines.add('- 판정 안내: ${assessment.guideText}');
  }

  for (final record in recentRecords) {
    lines.add('- $record');
  }

  return lines.join('\n');
}
