import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_error_message.dart';
import '../post_auth_route.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // 1. 사용자가 입력할 4가지 칸의 데이터를 담을 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController(); // 비밀번호 확인용

  // 2. 화면이 꺼질 때 메모리 누수 방지
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  // 3. ⭐️ 가입하기 버튼을 눌렀을 때 실행될 Supabase Auth 회원가입 함수
  Future<void> handleSignupSubmit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 빈칸 검사
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 정보를 입력해주세요.')),
      );
      return;
    }

    // 비밀번호가 서로 일치하는지 프론트엔드에서 1차 검사
    if (password != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 서로 일치하지 않습니다.')),
      );
      return;
    }

    // Supabase 기본 정책과 동일한 최소 길이를 미리 확인합니다.
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 6자 이상이어야 합니다.')),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        // 이 값이 auth.users.raw_user_meta_data에 저장되고,
        // handle_new_user 트리거가 profiles.name으로 복사합니다.
        data: {'name': name},
      );

      if (!mounted) return;

      if (response.session != null) {
        // 이메일 인증이 꺼져 있으면 가입 즉시 로그인 상태가 됩니다.
        // 갓 가입한 계정이라 아이가 없으므로 보통 온보딩으로 이어집니다.
        final destination = await nextRouteAfterSignIn();
        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(
          context,
          destination,
          (route) => false,
        );
      } else {
        // 이메일 인증이 켜져 있으면 인증을 마쳐야 로그인할 수 있습니다.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가입 확인 메일을 보냈습니다. 인증 후 로그인해주세요.')),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      // 원인 추적을 위해 원본 코드와 메시지를 로그에 남깁니다.
      debugPrint('회원가입 실패: code=${e.code} message=${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErrorMessage(e))),
      );
    } catch (e) {
      debugPrint('회원가입 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 연결을 확인해주세요.')),
        );
      }
    }
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
        // ★ 키보드가 올라와 화면이 좁아져도 오버플로가 나지 않도록 스크롤 레이아웃을 씁니다.
        //   (로그인 화면과 동일한 구조)
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
                        const Text(
                          '회원가입을 위해\n정보를 입력해주세요',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 이름 입력창
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: '이름',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 이메일 입력창
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: '이메일',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 비밀번호 입력창
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '비밀번호',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 비밀번호 확인 입력창
                        TextField(
                          controller: _passwordConfirmController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '비밀번호 확인',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // 가입하기 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: handleSignupSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '가입하기',
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
              ),
            );
          },
        ),
      ),
    );
  }
}