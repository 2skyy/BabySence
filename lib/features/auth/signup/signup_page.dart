import 'package:flutter/material.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 토스 감성의 깔끔한 배경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context), // 뒤로가기
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 키보드가 올라올 때를 대비해 스크롤 영역 설정
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // 1. 크고 명확한 헤드라인
                      const Text(
                        '회원가입을 위해\n정보를 입력해주세요',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // 2. 입력창 폼 (아래 _buildTextField 함수로 코드 간소화)
                      _buildTextField(hintText: '이름'),
                      const SizedBox(height: 32),
                      
                      _buildTextField(hintText: '이메일'),
                      const SizedBox(height: 32),
                      
                      _buildTextField(hintText: '비밀번호', obscureText: true),
                      const SizedBox(height: 32),
                      
                      _buildTextField(hintText: '비밀번호 확인', obscureText: true),
                      const SizedBox(height: 32), // 스크롤 시 하단 여유 공간
                    ],
                  ),
                ),
              ),
              
              // 3. 하단에 고정되는 메인 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 회원가입 API 연결 로직 추가
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3182F6), // 토스 블루
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
              const SizedBox(height: 16), // 아이폰 하단 바 등을 위한 여백
            ],
          ),
        ),
      ),
    );
  }

  // 반복되는 텍스트 필드 디자인을 한 곳에서 관리하기 위한 헬퍼 함수
  Widget _buildTextField({required String hintText, bool obscureText = false}) {
    return TextField(
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 18),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF3182F6), width: 2), // 포커스 시 파란색
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}