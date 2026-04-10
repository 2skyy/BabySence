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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  AppSpacing.xl,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildLoginForm(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildLoginButton(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildSignupButton(context),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('Login', style: AppTextStyles.headline),
        const SizedBox(height: AppSpacing.sm),
        Text('Welcome back', style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildLoginForm() {
    return const Column(
      children: [
        CommonTextField(hintText: 'Email'),
        SizedBox(height: AppSpacing.md),
        CommonTextField(hintText: 'Password', obscureText: true),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return CommonButton(
      text: 'Login',
      onPressed: () => handleLoginTap(context),
    );
  }

  Widget _buildSignupButton(BuildContext context) {
    return TextButton(
      onPressed: () => handleSignupTap(context),
      child: const Text('Go to Sign Up'),
    );
  }
}
