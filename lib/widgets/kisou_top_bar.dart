import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Shared top toolbar shown above every tab in the root shell.
///
/// Left: the KISOU brand lockup (image + wordmark). Right: an optional,
/// per-tab [action] widget (e.g. the home tab's feedback button). Living in
/// the shell means the logo stays put across tab switches instead of being
/// re-declared inside each screen.
class KisouTopBar extends StatelessWidget {
  const KisouTopBar({super.key, this.action});

  /// Optional action pinned to the trailing edge of the toolbar.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const BrandLogo(variant: BrandLogoVariant.lockup, size: 35),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}
