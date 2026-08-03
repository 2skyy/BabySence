import 'package:supabase_flutter/supabase_flutter.dart';

/// [AuthException]을 사용자에게 보여줄 한국어 문구로 바꿉니다.
///
/// 메시지 문자열을 뒤지지 않고 Supabase가 주는 `code`로 구분합니다.
/// 문자열 매칭(`message.contains('email')`)을 쓰면 원인이 다른 오류가 같은
/// 문구로 뭉개집니다. 실제로 서버에서 이메일 가입이 꺼져 있었을 때
/// "이메일 형식이 올바르지 않습니다"로 표시되어 원인을 찾기 어려웠습니다.
///
/// 코드 목록: https://supabase.com/docs/guides/auth/debugging/error-codes
String authErrorMessage(AuthException e) {
  switch (e.code) {
    // --- 사용자가 고칠 수 있는 것 ---
    case 'invalid_credentials':
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    case 'email_exists':
    case 'user_already_exists':
      return '이미 가입된 이메일입니다.';
    case 'email_address_invalid':
      return '이메일 형식이 올바르지 않습니다.';
    case 'weak_password':
      return '비밀번호가 너무 약합니다. 6자 이상으로 만들어주세요.';
    case 'email_not_confirmed':
      return '이메일 인증이 필요합니다. 메일함을 확인해주세요.';
    case 'same_password':
      return '이전과 다른 비밀번호를 사용해주세요.';

    // --- 잠시 뒤 다시 시도 ---
    case 'over_email_send_rate_limit':
      return '메일 발송 한도를 넘었습니다. 잠시 후 다시 시도해주세요.';
    case 'over_request_rate_limit':
      return '요청이 너무 잦습니다. 잠시 후 다시 시도해주세요.';

    // --- 서버 설정 문제. 사용자가 할 수 있는 게 없으므로 원인을 그대로 알립니다 ---
    case 'email_provider_disabled':
      return '이메일 가입이 꺼져 있습니다. Supabase 대시보드에서 Email provider를 켜야 합니다.';
    case 'signup_disabled':
      return '현재 회원가입이 중지되어 있습니다.';
    case 'provider_disabled':
      return '이 소셜 로그인이 꺼져 있습니다. Supabase 대시보드에서 provider를 켜야 합니다.';

    // --- 그 외 ---
    default:
      // 모르는 코드는 감추지 않고 그대로 노출합니다. 감추면 원인 추적이 막힙니다.
      final detail = e.code ?? e.message;
      return '요청을 처리하지 못했습니다. ($detail)';
  }
}
