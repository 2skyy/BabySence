import 'package:dio/dio.dart';
// MultipartFile은 dio와 http(supabase_flutter가 끌고 옵니다) 양쪽에 있습니다.
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../../../core/constants/api_config.dart';
import '../assessment/assessment.dart';

/// 사진 한 장을 보고 서버가 돌려준 것.
///
/// **진단이 아닙니다.** 병명도 확률도 없습니다. 보이는 것과 단계, 그리고
/// 지금 할 수 있는 것만 옵니다.
class SkinReading {
  /// 사진에서 보이는 것을 옮긴 문장들. 병명은 들어 있지 않습니다.
  final List<String> observations;

  /// 다른 화면과 같은 판정 단계(정상/주의/상담 권장).
  final AssessmentLevel level;

  /// 오늘 안에 진료가 필요해 보이는 경우.
  ///
  /// 단계를 하나 더 만드는 대신 따로 두었습니다 — 판정 단계는 DB 제약과
  /// 묶여 있어 늘리려면 마이그레이션이 필요합니다.
  final bool urgent;

  /// 보호자가 지금 할 수 있는 것.
  final String advice;

  /// 서버가 붙이는 고정 고지 문구.
  final String disclaimer;

  const SkinReading({
    required this.observations,
    required this.level,
    required this.urgent,
    required this.advice,
    required this.disclaimer,
  });
}

/// 판독 자체가 안 된 경우.
///
/// 피부가 아닌 사진, 너무 어둡거나 흐린 사진. **정상과 구별해야 합니다** —
/// 확인이 안 됐다는 것과 괜찮다는 것은 다른 말입니다.
class SkinUnreadable implements Exception {
  final String message;
  const SkinUnreadable(this.message);

  @override
  String toString() => message;
}

class SkinException implements Exception {
  final String message;
  const SkinException(this.message);

  @override
  String toString() => message;
}

/// 피부 사진을 서버에 보냅니다.
///
/// **Claude를 앱에서 직접 부르지 않습니다.** API 키를 앱에 넣으면 패키지를
/// 뜯어 꺼낼 수 있습니다. 키는 FastAPI 서버의 환경변수에만 있습니다.
class SkinService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      // 사진을 올리고 모델이 보는 시간까지 포함합니다.
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  static Future<SkinReading> analyze(String imagePath) async {
    final token = await _accessToken();

    final Response response;
    try {
      response = await _dio.post(
        ApiConfig.skinDiagnose,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(imagePath, filename: 'skin.jpg'),
        }),
      );
    } on DioException catch (e) {
      throw SkinException(_messageFor(e));
    }

    final data = response.data as Map;

    if (data['status'] == 'unreadable') {
      throw SkinUnreadable(
        data['message'] as String? ??
            '사진에서 피부를 확인하지 못했습니다. 밝은 곳에서 다시 찍어 주세요.',
      );
    }

    return SkinReading(
      observations: [
        for (final o in (data['observations'] as List? ?? [])) o.toString(),
      ],
      level: _levelFrom(data['level'] as String?),
      urgent: data['urgent'] as bool? ?? false,
      advice: data['advice'] as String? ?? '',
      disclaimer: data['disclaimer'] as String? ?? '',
    );
  }

  /// 서버의 level 문자열을 앱의 판정 단계로 옮깁니다.
  ///
  /// 모르는 값이 오면 **높은 쪽으로** 붙입니다. 낮은 쪽으로 떨어뜨리면
  /// 서버가 무엇을 보냈든 화면은 '정상'이 됩니다.
  static AssessmentLevel _levelFrom(String? raw) {
    switch (raw) {
      case 'normal':
        return AssessmentLevel.normal;
      case 'caution':
        return AssessmentLevel.caution;
      default:
        return AssessmentLevel.consult;
    }
  }

  /// 서버에 보낼 Supabase 액세스 토큰.
  ///
  /// 사진 한 장마다 Claude 크레딧을 씁니다. 인증이 없으면 서버 주소를 아는
  /// 누구나 크레딧을 태울 수 있습니다.
  static Future<String> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;

    if (session == null) {
      throw const SkinException('로그인이 필요합니다.');
    }

    if (session.isExpired) {
      try {
        session = (await auth.refreshSession()).session;
      } catch (_) {
        throw const SkinException('로그인이 만료되었습니다. 다시 로그인해 주세요.');
      }
      if (session == null) {
        throw const SkinException('로그인이 만료되었습니다. 다시 로그인해 주세요.');
      }
    }

    return session.accessToken;
  }

  /// 서버가 상황별 한국어 문구를 내려주므로 그대로 씁니다.
  /// 그 밖의 경우만 앱에서 문구를 만듭니다.
  ///
  /// 예전에는 `"서버 연동 실패: $e"`로 예외를 그대로 붙여, 화면에
  /// `DioException [bad response]: ... 503` 영문 원문이 떴습니다.
  static String _messageFor(DioException e) {
    final detail =
        (e.response?.data is Map) ? (e.response!.data as Map)['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return '분석 서버에 연결하지 못했습니다. 서버가 켜져 있는지 확인해 주세요.';
      case DioExceptionType.receiveTimeout:
        return '분석이 끝나지 않았습니다. 잠시 후 다시 시도해 주세요.';
      default:
        return '사진을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}
