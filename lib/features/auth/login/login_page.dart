import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 서버와 통신하는 이메일 로그인 함수
  Future<void> handleLoginTap(BuildContext context) async {
    final url = Uri.parse('http://127.0.0.1:8080/api/users/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 3)); // 3초 동안 응답 없으면 타임아웃

      if (response.statusCode == 200) {
        print('로그인 성공!');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
                (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이메일이나 비밀번호를 확인해주세요.')),
          );
        }
      }
    } catch (e) {
      // 🚨 [테스트용 예외 처리] 서버가 꺼져있거나 IP가 안 맞아도 홈 화면으로 진입할 수 있게 합니다.
      print('서버 연결 실패($e) -> 테스트 모드로 홈 화면 진입');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버 연결 실패: 테스트 모드로 진입합니다.'),
            duration: Duration(seconds: 2),
          ),
        );

        // 2초 뒤에 자동으로 홈 화면으로 이동시켜 줍니다.
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
                  (route) => false,
            );
          }
        });
      }
    }
  }

  void handleSignupTap(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  void handleSocialLogin(BuildContext context, String provider) {
    print('$provider 로그인 클릭됨 -> 테스트 모드로 홈 화면 진입');
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3182F6).withOpacity(0.1),
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

                      // 이메일 입력창
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
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

                      // 비밀번호 입력창
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

                      // 스크롤 뷰 내부에서 유연하게 밀어내기 위해 고정 높이 대신 가변 스페이서 배치
                      const SizedBox(height: 60),

                      Center(
                        child: Text(
                          '또는 SNS로 간편하게 시작하기',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 소셜 로그인 버튼 영역
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
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => handleLoginTap(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3182F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '로그인하기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

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
              color: Colors.black.withOpacity(0.06),
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