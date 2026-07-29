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
    final compact = usesLargeText(context);
    void openOutlook() {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const OutlookScreen()));
    }

    return Semantics(
      button: true,
      label: AppStrings.forecastOutlookEntry,
      onTap: openOutlook,
      child: ExcludeSemantics(
        child: Tooltip(
          message: AppStrings.forecastOutlookEntry,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: openOutlook,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: compact ? 48 : 0,
                  minHeight: 48,
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: c.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: c.accent,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: KisouTheme.gapXs),
                        Text(
                          AppStrings.forecastOutlookEntry,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
