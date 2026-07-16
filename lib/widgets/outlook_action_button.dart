import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../screens/forecast/outlook_screen.dart';

/// The 予報 tab's toolbar action: opens the full-page date/place lookup.
/// Mirrors the visual language of the home tab's feedback pill.
class OutlookActionButton extends StatelessWidget {
  const OutlookActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const OutlookScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: KisouTheme.accent,
              ),
              const SizedBox(width: KisouTheme.gapXs),
              Text(
                AppStrings.forecastOutlookEntry,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
