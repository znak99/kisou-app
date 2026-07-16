import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';

/// 予報 tab: tomorrow's outfit, a feedback nudge, and a date/place lookup.
/// Sections land in FE-3; this shell only fixes the tab wiring.
class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(KisouTheme.gapM),
      children: [
        Text(
          AppStrings.forecastTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}
