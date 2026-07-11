import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';

enum BrandLogoVariant { mark, lockup }

/// The キソウ brand logo. [BrandLogoVariant.mark] is the clay sun+tee symbol;
/// [BrandLogoVariant.lockup] pairs the mark with the キソウ wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.variant = BrandLogoVariant.lockup,
    this.size = 32,
  });

  final BrandLogoVariant variant;

  /// Height of the mark in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      'assets/brand/logo_mark.svg',
      width: size,
      height: size,
    );
    if (variant == BrandLogoVariant.mark) {
      return mark;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: size * 0.82,
            fontWeight: FontWeight.w800,
            color: KisouTheme.ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
