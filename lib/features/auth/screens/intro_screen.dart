import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';
import '../../../core/widgets/app_gradient_button.dart';
import '../widgets/app_logo.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32), // replaced AppSpacing.xl
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(),
              const SizedBox(height: 28),
              AppGradientButton(
                label: 'Click to start',
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
