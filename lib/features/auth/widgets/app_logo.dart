import 'package:flutter/material.dart';
import '../../../core/theme/theme_v2.dart';

class AppLogo extends StatelessWidget {
  final String? subtitle;
  final String assetPath; // e.g. 'assets/images/logo.png'
  final double size;

  const AppLogo({
    super.key,
    this.subtitle,
    this.assetPath = 'assets/images/logo.png',
    this.size = 220, // bigger default
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transparent circle with your logo centered inside
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent, // fully transparent circle
          ),
          child: Center(
            child: Image.asset(
              assetPath,
              width: size * 0.9, // make logo bigger inside the circle
              height: size * 0.9,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Optional subtitle (kept as-is)
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF7DE8DE)),
          ),
        ],
      ],
    );
  }
}
