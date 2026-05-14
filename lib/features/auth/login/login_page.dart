import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void handleLoginTap(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.home);
  }

  void handleSignupTap(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 토스 특유의 깔끔한 흰색 배경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context), // 뒤로가기 버튼
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // 좌우 여백 넉넉하게
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 핵심: 좌측 정렬
            children: [
              const SizedBox(height: 20),
              // 1. 크고 명확한 헤드라인 텍스트
              const Text(
                '이메일과 비밀번호를\n입력해주세요',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.4, // 줄간격
                ),
              ),
              const SizedBox(height: 48),
              
              // 2. 심플한 이메일 입력창 (밑줄만 있는 형태)
              TextField(
                decoration: InputDecoration(
                  hintText: '이메일',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 18),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2), // 토스 블루
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
              
              // 3. 심플한 비밀번호 입력창
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 18),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF3182F6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // 4. 은은한 회원가입 링크
              GestureDetector(
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
              
              const Spacer(), // 남은 공간을 밀어내서 버튼을 하단으로 고정
              
              // 5. 하단을 꽉 채우는 둥근 메인 버튼
              SizedBox(
                width: double.infinity,
                height: 56, // 터치하기 편한 큼직한 높이
                child: ElevatedButton(
                  onPressed: () => handleLoginTap(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3182F6), // 토스 블루 컬러
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // 적당히 둥근 모서리
                    ),
                    elevation: 0, // 그림자 제거로 플랫한 느낌
                  ),
                  child: const Text(
                    '로그인',
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
}