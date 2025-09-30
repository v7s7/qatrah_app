import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';

class AppLogo extends StatelessWidget {
  final String? subtitle;

  const AppLogo({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo shape (circle + drop icon placeholder)
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradient.primary,
          ),
          child: const Center(
            child: Text(
              "قطرة",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "QATRAH",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.cyanAccent),
          ),
        ],
      ],
    );
  }
}
