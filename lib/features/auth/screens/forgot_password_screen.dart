import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';
import '../../../core/widgets/app_gradient_button.dart';
import '../../../core/widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Forgot password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AppTextField(
              controller: emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            AppGradientButton(
              label: 'Send reset link',
              onPressed: () {
                // TODO: trigger reset
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
