import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../routes/app_routes.dart';

// 입력 컨트롤러를 사용하기 위해 StatefulWidget으로 변경되었습니다.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 💡 팀원 코드를 받으면서 바뀐 주소를 우리 컴퓨터 로컬(adb reverse) 주소로 고쳐줍니다.
  final String _baseUrl = 'http://127.0.0.1:8080';

  // 1. 입력값을 저장할 텍스트 컨트롤러 생성
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggingIn = false;

  // 2. 메모리 누수를 막기 위해 화면이 꺼질 때 컨트롤러 해제
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 3. 서버와 통신하는 이메일 로그인 함수
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

    final url = Uri.parse('$_baseUrl/api/users/login');

    try {
      setState(() => _isLoggingIn = true);

      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
              (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인에 실패했습니다. (상태 코드: ${response.statusCode})'),
          ),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 요청이 지연되고 있습니다. 서버 상태를 확인해주세요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버와 연결할 수 없습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  // 회원가입 페이지 이동 함수
  void handleSignupTap(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  // 임시 소셜 로그인 처리 함수
  void handleSocialLogin(BuildContext context, String provider) {
    debugPrint('$provider 로그인 클릭됨');
    // 추후 서버 연동 시 로직 추가
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                            color: const Color(0xFF3182F6).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.child_care,
                            color: Color(0xFF3182F6),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '이메일과 비밀번호를\n입력해주세요',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ⭐️ 컨트롤러가 연결된 이메일 입력창
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress, // 이메일 키보드 모드
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
                            hintText: '이메일',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                            hintText: '비밀번호',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                                color: Colors.grey[500],
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
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
                              onTap: () => handleSocialLogin(context, 'Kakao'),
                            ),
                            const SizedBox(width: 20),
                            _buildSocialImageButton(
                              imagePath: 'assets/images/google_logo.png',
                              backgroundColor: Colors.white,
                              onTap: () => handleSocialLogin(context, 'Google'),
                              hasBorder: true,
                            ),
                            const SizedBox(width: 20),
                            _buildSocialImageButton(
                              imagePath: 'assets/images/apple_logo.png',
                              backgroundColor: Colors.black,
                              onTap: () => handleSocialLogin(context, 'Apple'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : handleLoginTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3182F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoggingIn
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text(
                              '로그인하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
          border: hasBorder ? Border.all(color: Colors.grey[200]!) : null,
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