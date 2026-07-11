import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';

/// Placeholder for an adaptive banner ad, pinned above the bottom navigation on
/// every tab. Swapping in a real AdMob banner later only touches this widget.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key});

  @override
  Widget build(BuildContext context) {
    // Adaptive-banner heuristic: taller on wide screens, standard elsewhere.
    final width = MediaQuery.sizeOf(context).width;
    final height = width >= 728 ? 90.0 : 56.0;
    return Container(
      width: double.infinity,
      height: height,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: KisouTheme.sand,
        border: Border(
          top: BorderSide(color: KisouTheme.hairline),
          bottom: BorderSide(color: KisouTheme.hairline),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: KisouTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KisouTheme.hairline),
            ),
            child: Text(
              'Ad',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: KisouTheme.softInk,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppStrings.adLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: KisouTheme.softInk,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
