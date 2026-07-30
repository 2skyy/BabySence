import 'package:flutter/foundation.dart';

/// AI 분석 서버(FastAPI) 주소.
///
/// 일반 데이터(기록 CRUD, 인증)는 Supabase가 직접 처리하므로, 이 서버는
/// 피부 추론만 담당합니다.
///
/// 주소는 실행 시 덮어쓸 수 있습니다.
///
///   flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://192.168.0.10:8000
///
/// 기본값이 플랫폼마다 다른 이유: 안드로이드 에뮬레이터에서 127.0.0.1은
/// 에뮬레이터 자신을 가리킵니다. 개발 PC는 10.0.2.2로 접근해야 합니다.
/// 실기기에서는 두 기본값 모두 닿지 않으므로 API_BASE_URL을 넘겨야 합니다.
class ApiConfig {
  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  /// 피부 사진 진단. multipart 필드명은 file.
  static String get skinDiagnose => '$baseUrl/api/skin/diagnose';
}
