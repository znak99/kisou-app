import 'package:flutter/material.dart';

enum BrandLogoVariant { mark, lockup }

/// The KISOU brand logo.
/// - [BrandLogoVariant.mark] is the clay clothing image logo.
/// - [BrandLogoVariant.lockup] pairs the image logo with the KISOU wordmark
///   (the wordmark swaps light/dark to stay legible on the current theme).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.variant = BrandLogoVariant.lockup,
    this.size = 32,
  });

  final BrandLogoVariant variant;

  /// Height of the image mark in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordmark = isDark
        ? 'assets/brand/text_logo_dark.png'
        : 'assets/brand/text_logo_light.png';

    final mark = Image.asset(
      'assets/brand/image_logo.png',
      height: size,
      fit: BoxFit.contain,
    );
    if (variant == BrandLogoVariant.mark) {
      return mark;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: size * 0.2),
        Image.asset(wordmark, height: size * 0.66, fit: BoxFit.contain),
      ],
    );
  }
}
