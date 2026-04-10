import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/common_button.dart';
import '../../../core/widgets/common_text_field.dart';
import '../../../routes/app_routes.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void handleLoginTap(BuildContext context) {
    navigateToHome(context);
  }

  void handleSignupTap(BuildContext context) {
    navigateToSignup(context);
  }

  void navigateToHome(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.home);
  }

  void navigateToSignup(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Login', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.xl),
              const CommonTextField(hintText: 'Email'),
              const SizedBox(height: AppSpacing.md),
              const CommonTextField(hintText: 'Password', obscureText: true),
              const SizedBox(height: AppSpacing.xl),
              CommonButton(
                text: 'Login',
                onPressed: () => handleLoginTap(context),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => handleSignupTap(context),
                child: const Text('Go to Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
