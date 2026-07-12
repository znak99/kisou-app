import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Branded splash rendered in Flutter: the image logo and the KISOU text logo
/// are two SEPARATE images stacked vertically and centered. The text logo
/// swaps light/dark to stay legible on the current theme.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordmark = isDark
        ? 'assets/brand/text_logo_dark.png'
        : 'assets/brand/text_logo_light.png';
    return Scaffold(
      backgroundColor: context.kisou.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/image_logo.png',
              width: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Image.asset(
              wordmark,
              width: 180,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
