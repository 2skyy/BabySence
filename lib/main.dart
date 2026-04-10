import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login/login_page.dart';
import 'features/auth/signup/signup_page.dart';
import 'features/detail/detail_page.dart';
import 'features/home/home_page.dart';
import 'features/mypage/mypage_page.dart';
import 'features/settings/settings_page.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BabySence',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.signup: (context) => const SignupPage(),
        AppRoutes.home: (context) => const HomePage(),
        AppRoutes.detail: (context) => const DetailPage(),
        AppRoutes.mypage: (context) => const MyPagePage(),
        AppRoutes.settings: (context) => const SettingsPage(),
      },
    );
  }
}
