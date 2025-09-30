import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';
import '../../../core/widgets/app_gradient_button.dart';
import '../../../core/widgets/app_text_field.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final confirmController = TextEditingController();

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Sign up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AppTextField(controller: firstController, hintText: 'First name'),
            const SizedBox(height: 12),
            AppTextField(controller: lastController, hintText: 'Last name'),
            const SizedBox(height: 12),
            AppTextField(
              controller: emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: passController,
              hintText: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: confirmController,
              hintText: 'Re-enter password',
              obscureText: true,
            ),
            const SizedBox(height: 24),
            AppGradientButton(
              label: 'Sign up',
              onPressed: () {
                // TODO: validate + call API
                Navigator.pop(context); // back to login after fake success
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
