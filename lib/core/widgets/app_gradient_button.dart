import 'package:flutter/material.dart';
import '../theme/theme_v2.dart';

class AppGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppGradientButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradient.primary,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
