import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_config.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final String _baseUrl = ApiConfig.baseUrl;
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

  // 3. ⭐️ 가입하기 버튼을 눌렀을 때 실행될 백엔드 통신 함수
  Future<void> handleSignupSubmit() async {
    // 빈칸 검사
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 정보를 입력해주세요.')),
      );
      return;
    }

    // 비밀번호가 서로 일치하는지 프론트엔드에서 1차 검사
    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 서로 일치하지 않습니다.')),
      );
      return;
    }

    final url = Uri.parse('$_baseUrl/api/users/join');

    try {
      // 스프링 부트 서버로 POST 요청 보내기
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'email': _emailController.text,
          'password': _passwordController.text, // 엔티티 변수명과 완벽히 일치
        }),
      );

      // 서버 응답 확인
      if (response.statusCode == 200) {
        // 서버에서 return "회원가입 성공!"; 이라고 보냈으므로 200(성공)이 뜹니다.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입이 완료되었습니다! 로그인해주세요.')),
          );
          Navigator.pop(context); // 가입 성공 시 로그인 화면으로 자동 이동
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('회원가입 실패 (상태 코드: ${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      print('서버 연결 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버와 연결할 수 없습니다. 서버가 켜져 있는지 확인해주세요.')),
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
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
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
                    backgroundColor: const Color(0xFF3182F6),
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
    );
  }
}