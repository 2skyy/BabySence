import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_button.dart';
import '../../routes/app_routes.dart';
import 'auth_error_message.dart';
import 'post_auth_route.dart';

// 입력 컨트롤러를 사용하기 위해 StatefulWidget으로 변경되었습니다.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// 소셜 로그인 후 브라우저가 앱으로 돌아올 때 사용하는 딥링크 주소.
/// AndroidManifest.xml의 intent-filter, Supabase 대시보드의 Redirect URLs와
/// 세 곳이 모두 같아야 합니다.
const String _oauthRedirectUrl = 'babysense://login-callback';

class _LoginPageState extends State<LoginPage> {
  // 1. 입력값을 저장할 텍스트 컨트롤러 생성
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggingIn = false;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    // 로그인 성공 시 홈으로 보내는 지점을 여기 한 곳으로 모읍니다.
    // 소셜 로그인은 브라우저를 다녀온 뒤에야 완료되므로 버튼 함수에서는
    // 이동 시점을 알 수 없기 때문입니다.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      if (!mounted || state.event != AuthChangeEvent.signedIn) return;

      // 회원가입 화면이 위에 떠 있는 동안에는 그쪽이 이동을 처리합니다.
      if (ModalRoute.of(context)?.isCurrent != true) return;

      // 등록된 아이가 없으면 먼저 온보딩을 거칩니다.
      final destination = await nextRouteAfterSignIn();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        destination,
            (route) => false,
      );
    });
  }

  // 2. 메모리 누수를 막기 위해 화면이 꺼질 때 컨트롤러 해제
  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 3. Supabase Auth 이메일 로그인 함수
  Future<void> handleLoginTap() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    try {
      setState(() => _isLoggingIn = true);

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // 성공 시 홈 이동은 initState의 onAuthStateChange 리스너가 처리합니다.
    } on AuthException catch (e) {
      if (!mounted) return;
      // 원인 추적을 위해 원본 코드와 메시지를 로그에 남깁니다.
      debugPrint('로그인 실패: code=${e.code} message=${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 연결을 확인해주세요. $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  // 회원가입 페이지 이동 함수
  void handleSignupTap(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  // 소셜 로그인. 브라우저에서 로그인을 마치면 딥링크로 앱에 돌아오고,
  // onAuthStateChange 리스너가 홈으로 이동시킵니다.
  //
  // 소셜 로그인은 가입과 로그인이 구분되지 않습니다. 처음 누르는 사용자는
  // 그 자리에서 계정이 만들어지고 handle_new_user 트리거가 profiles를 채웁니다.
  Future<void> handleSocialLogin(OAuthProvider provider) async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectUrl,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      debugPrint('소셜 로그인 실패: code=${e.code} message=${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 창을 열 수 없습니다. $e')),
      );
    }
  }

  // 애플 로그인은 Apple Developer Program(연 $99) 가입이 필요해 보류 중입니다.
  void handleApplePending() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('애플 로그인은 iOS 배포 시 지원 예정입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        // 로그인은 첫 화면이라 뒤로 갈 곳이 없습니다.
        // 뒤로가기 버튼을 두면 스택이 비어 빈 화면이 됩니다.
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        // ★ 핵심 고정: 팀원 코드로 유실되었던 키보드 밀림 에러 방지용 스크롤 레이아웃을 다시 복구합니다.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.child_care,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '이메일과 비밀번호를\n입력해주세요',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ⭐️ 컨트롤러가 연결된 이메일 입력창
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress, // 이메일 키보드 모드
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined, color: context.colors.textSecondary),
                            hintText: '이메일',
                            hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.colors.border),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.colors.border),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ⭐️ 컨트롤러가 연결된 비밀번호 입력창
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline, color: context.colors.textSecondary),
                            hintText: '비밀번호',
                            hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.colors.border),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: context.colors.border),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => handleSignupTap(context),
                            child: Text(
                              '아직 계정이 없으신가요?',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Center(
                          child: Text(
                            '또는 SNS로 간편하게 시작하기',
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 이미지 에셋을 사용하는 소셜 로그인 버튼 영역
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialImageButton(
                              imagePath: 'assets/images/kakao_logo.png',
                              backgroundColor: const Color(0xFFFEE500),
                              onTap: () => handleSocialLogin(OAuthProvider.kakao),
                            ),
                            const SizedBox(width: 20),
                            _buildSocialImageButton(
                              imagePath: 'assets/images/google_logo.png',
                              // 테마 예외: 구글 로그인 버튼은 브랜드 가이드가
                              // 흰 바탕을 요구해 다크 모드에서도 그대로 둡니다.
                              backgroundColor: Colors.white,
                              onTap: () => handleSocialLogin(OAuthProvider.google),
                              hasBorder: true,
                            ),
                            const SizedBox(width: 20),
                            _buildSocialImageButton(
                              imagePath: 'assets/images/apple_logo.png',
                              backgroundColor: Colors.black,
                              onTap: handleApplePending,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        CommonButton(
                          text: '로그인하기',
                          onPressed: handleLoginTap,
                          isLoading: _isLoggingIn,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 커스텀 이미지 버튼 위젯
  Widget _buildSocialImageButton({
    required String imagePath,
    required Color backgroundColor,
    required VoidCallback onTap,
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: hasBorder ? Border.all(color: context.colors.border) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}