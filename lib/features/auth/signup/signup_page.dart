import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/common_app_bar.dart';
import '../../../core/widgets/common_button.dart';
import '../../../core/widgets/common_text_field.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'Sign Up'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const CommonTextField(hintText: 'Name'),
            const SizedBox(height: AppSpacing.md),
            const CommonTextField(hintText: 'Email'),
            const SizedBox(height: AppSpacing.md),
            const CommonTextField(hintText: 'Password', obscureText: true),
            const SizedBox(height: AppSpacing.md),
            const CommonTextField(
              hintText: 'Confirm Password',
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            CommonButton(text: 'Sign Up', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
