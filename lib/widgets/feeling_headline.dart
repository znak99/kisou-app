import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';

/// Hero card on the home screen: a 7-step comfort prediction phrase colored by
/// the feeling level, e.g. "今日の◯◯さんは / とても暑く感じるでしょう".
class FeelingHeadline extends StatelessWidget {
  const FeelingHeadline({super.key, required this.feeling, this.nickname});

  final String feeling;
  final String? nickname;

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
    final name = nickname?.trim() ?? '';
    final lead = name.isEmpty
        ? AppStrings.feelingLead
        : AppStrings.feelingLeadNamed(name);
    return Semantics(
      container: true,
      label: '$lead $phrase',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(color, Colors.white, 0.12)!, color],
            ),
            borderRadius: BorderRadius.circular(KisouTheme.rLg),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KisouTheme.feelingForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phrase,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: KisouTheme.feelingForeground,
                            fontSize: 19,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KisouTheme.gapM),
              Icon(icon, color: KisouTheme.feelingForeground, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}
