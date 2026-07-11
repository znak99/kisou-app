import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';

/// Hero card on the home screen: a 7-step comfort prediction phrase colored by
/// the feeling level, e.g. "今日のあなたは / とても暑く感じるでしょう".
class FeelingHeadline extends StatelessWidget {
  const FeelingHeadline({super.key, required this.feeling});

  final String feeling;

  static const _phrases = {
    'VERY_HOT': AppStrings.feelingVeryHot,
    'HOT': AppStrings.feelingHot,
    'WARM': AppStrings.feelingWarm,
    'PERFECT': AppStrings.feelingPerfect,
    'COOL': AppStrings.feelingCool,
    'COLD': AppStrings.feelingCold,
    'VERY_COLD': AppStrings.feelingVeryCold,
  };

  static const _icons = {
    'VERY_HOT': Icons.local_fire_department_rounded,
    'HOT': Icons.wb_sunny_rounded,
    'WARM': Icons.wb_twilight_rounded,
    'PERFECT': Icons.sentiment_satisfied_rounded,
    'COOL': Icons.air_rounded,
    'COLD': Icons.ac_unit_rounded,
    'VERY_COLD': Icons.severe_cold_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = KisouTheme.feelingColor(feeling);
    final phrase = _phrases[feeling] ?? AppStrings.feelingPerfect;
    final icon = _icons[feeling] ?? Icons.sentiment_satisfied_rounded;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.82)],
        ),
        borderRadius: BorderRadius.circular(KisouTheme.rLg),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.feelingLead,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phrase,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: Colors.white, size: 44),
        ],
      ),
    );
  }
}
