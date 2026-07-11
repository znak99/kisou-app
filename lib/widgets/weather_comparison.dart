import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../models/weather.dart' as weather_model;

class WeatherComparison extends StatelessWidget {
  const WeatherComparison({super.key, required this.comparison});

  final weather_model.WeatherComparison comparison;

  @override
  Widget build(BuildContext context) {
    final highDiff =
        comparison.today.tempHigh.round() -
        comparison.yesterday.tempHigh.round();
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 18),
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

  final int diff;

  @override
  Widget build(BuildContext context) {
    final color = diff > 0
        ? KisouTheme.warm
        : diff < 0
        ? KisouTheme.cool
        : KisouTheme.softInk;
    final icon = diff > 0
        ? Icons.arrow_upward_rounded
        : diff < 0
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;
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

  String _comparisonText(int diff) {
    if (diff > 0) {
      return '昨日より$diff°';
    }
    if (diff < 0) {
      return '昨日より${diff.abs()}°';
    }
    return '昨日と同じ';
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: emphasized ? KisouTheme.sand : Colors.transparent,
        borderRadius: BorderRadius.circular(KisouTheme.rSm),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              color: emphasized ? KisouTheme.ink : KisouTheme.softInk,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.tempHigh.round()}°',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: KisouTheme.warm,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${summary.tempLow.round()}°',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: KisouTheme.cool,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
