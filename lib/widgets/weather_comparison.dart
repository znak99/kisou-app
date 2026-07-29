import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../models/weather.dart' as weather_model;

String _fmtTemp(double? value) => value == null ? '—' : '${value.round()}°';

class WeatherComparison extends StatelessWidget {
  const WeatherComparison({super.key, required this.comparison});

  final weather_model.WeatherComparison comparison;

  @override
  Widget build(BuildContext context) {
    final largeText = usesLargeText(context);
    final todayHigh = comparison.today.tempHigh;
    final yesterdayHigh = comparison.yesterday.tempHigh;
    final highDiff = (todayHigh != null && yesterdayHigh != null)
        ? todayHigh.round() - yesterdayHigh.round()
        : null;
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (largeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.weatherComparisonSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: KisouTheme.gapS),
                _DiffPill(diff: highDiff),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.weatherComparisonSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _DiffPill(diff: highDiff),
              ],
            ),
          const SizedBox(height: KisouTheme.gapL),
          if (largeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeatherColumn(
                  label: AppStrings.today,
                  summary: comparison.today,
                  emphasized: true,
                ),
                const SizedBox(height: KisouTheme.gapS),
                _WeatherColumn(
                  label: AppStrings.yesterday,
                  summary: comparison.yesterday,
                ),
                const SizedBox(height: KisouTheme.gapS),
                _WeatherColumn(
                  label: AppStrings.twoDaysAgo,
                  summary: comparison.twoDaysAgo,
                ),
              ],
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _WeatherColumn(
                      label: AppStrings.today,
                      summary: comparison.today,
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WeatherColumn(
                      label: AppStrings.yesterday,
                      summary: comparison.yesterday,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WeatherColumn(
                      label: AppStrings.twoDaysAgo,
                      summary: comparison.twoDaysAgo,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiffPill extends StatelessWidget {
  const _DiffPill({required this.diff});

  final int? diff;

  @override
  Widget build(BuildContext context) {
    final d = diff;
    final c = context.kisou;
    final color = (d == null || d == 0)
        ? c.softInk
        : d > 0
        ? c.warm
        : c.cool;
    final icon = (d == null || d == 0)
        ? Icons.remove_rounded
        : d > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            _comparisonText(diff),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _comparisonText(int? diff) {
    if (diff == null) {
      return '—';
    }
    if (diff == 0) {
      return AppStrings.sameAsYesterday;
    }
    return AppStrings.comparedToYesterday(diff.abs());
  }
}

class _WeatherColumn extends StatelessWidget {
  const _WeatherColumn({
    required this.label,
    required this.summary,
    this.emphasized = false,
  });

  final String label;
  final weather_model.WeatherSummary summary;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: emphasized ? context.kisou.surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(KisouTheme.rSm),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              color: emphasized ? context.kisou.ink : context.kisou.softInk,
            ),
          ),
          const SizedBox(height: KisouTheme.gapS),
          Text(
            _fmtTemp(summary.tempHigh),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: c.warm,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _fmtTemp(summary.tempLow),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.cool,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
