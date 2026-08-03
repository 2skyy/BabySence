import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_project/features/auth/auth_error_message.dart';

/// 인증 오류를 원인별로 구분해 보여주는지 확인합니다.
///
/// 이전에는 메시지 문자열에 'email'이 들어있는지로 판단해서, 서버 설정 문제가
/// "이메일 형식이 올바르지 않습니다"로 표시됐습니다. 실제로 원인을 찾는 데
/// 시간을 썼던 문제라 회귀를 막습니다.
void main() {
  AuthException err(String code, [String message = 'some message']) =>
      AuthException(message, code: code);

  test('서버 설정 문제는 사용자 입력 문제로 보이지 않는다', () {
    final m = authErrorMessage(err('email_provider_disabled'));

    expect(m, contains('Email provider'));
    // 예전처럼 형식 문제로 뭉개지면 안 됩니다.
    expect(m, isNot(contains('형식')));
  });

  test('소셜 provider가 꺼진 경우도 원인이 드러난다', () {
    expect(authErrorMessage(err('provider_disabled')), contains('provider'));
  });

  test('입력 문제는 사용자가 고칠 수 있는 안내를 준다', () {
    expect(authErrorMessage(err('invalid_credentials')), contains('비밀번호'));
    expect(authErrorMessage(err('email_exists')), contains('이미 가입'));
    expect(authErrorMessage(err('email_address_invalid')), contains('형식'));
    expect(authErrorMessage(err('weak_password')), contains('6자'));
    expect(authErrorMessage(err('email_not_confirmed')), contains('인증'));
  });

  test('한도 초과는 다시 시도하라고 안내한다', () {
    expect(authErrorMessage(err('over_email_send_rate_limit')),
        contains('잠시 후'));
    expect(authErrorMessage(err('over_request_rate_limit')), contains('잠시 후'));
  });

  test('email_exists와 email_address_invalid를 구분한다', () {
    // 둘 다 메시지에 'email'이 들어가지만 원인이 다릅니다.
    expect(authErrorMessage(err('email_exists')),
        isNot(authErrorMessage(err('email_address_invalid'))));
  });

  test('모르는 코드는 감추지 않고 그대로 노출한다', () {
    // 감추면 원인 추적이 막힙니다.
    expect(authErrorMessage(err('some_new_code')), contains('some_new_code'));
  });

  test('code가 없으면 원본 메시지를 보여준다', () {
    // 응답을 받기 전에 발생한 오류는 code가 없습니다.
    final m = authErrorMessage(AuthException('Network is unreachable'));
    expect(m, contains('Network is unreachable'));
  });
}
