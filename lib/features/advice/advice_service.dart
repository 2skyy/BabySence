import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/api_config.dart';
import '../detail/assessment/assessment.dart';
import 'chat_message.dart';

/// 서버가 돌려준 답변.
class Advice {
  final String answer;

  /// 서버가 붙이는 고정 고지 문구. 모델이 쓰지 않습니다.
  final String disclaimer;

  /// 토큰 상한에 걸려 문장이 중간에 끊긴 경우.
  ///
  /// 끊긴 답을 완성된 답인 것처럼 보여주면 보호자가 잘린 문장을 결론으로
  /// 읽습니다.
  final bool truncated;

  const Advice({
    required this.answer,
    required this.disclaimer,
    this.truncated = false,
  });
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

  /// 대화를 이어 답변을 받습니다.
  ///
  /// [messages]의 마지막은 보호자의 말이어야 합니다. 서버가 대화를 저장하지
  /// 않으므로 매번 전체를 보냅니다.
  ///
  /// [context]는 앱이 조립합니다 — 서버는 DB에 붙지 않아 기록을 직접
  /// 조회할 수 없습니다. 아이 이름 같은 식별 정보는 넣지 마세요.
  static Future<Advice> ask({
    required List<ChatMessage> messages,
    required AssessmentDomain domain,
    String? context,
  }) async {
    final token = await _accessToken();

    try {
      final response = await _dio.post(
        ApiConfig.advice,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'messages': [
            for (final m in trimForRequest(messages)) m.toJson(),
          ],
          // enum 이름이 서버의 DOMAINS 키와 같습니다.
          'domain': domain.name,
          if (context != null && context.isNotEmpty) 'context': context,
        },
      );

      final data = response.data as Map;
      return Advice(
        answer: data['answer'] as String,
        disclaimer: data['disclaimer'] as String,
        truncated: data['truncated'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw AdviceException(_messageFor(e));
    }
  }

  /// 서버에 보낼 Supabase 액세스 토큰.
  ///
  /// 서버는 이 토큰으로 로그인한 사용자인지 확인합니다. 인증이 없으면 서버
  /// 주소를 아는 누구나 Claude 크레딧을 태울 수 있기 때문입니다.
  ///
  /// 만료된 토큰을 그냥 보내면 서버가 401을 내고 사용자는 이유를 모릅니다.
  /// 여기서 한 번 갱신해 봅니다.
  static Future<String> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;

    if (session == null) {
      throw const AdviceException('로그인이 필요합니다.');
    }

    if (session.isExpired) {
      try {
        session = (await auth.refreshSession()).session;
      } catch (_) {
        throw const AdviceException('로그인이 만료되었습니다. 다시 로그인해 주세요.');
      }
      if (session == null) {
        throw const AdviceException('로그인이 만료되었습니다. 다시 로그인해 주세요.');
      }
    }

    return session.accessToken;
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
