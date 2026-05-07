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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.weatherComparisonSection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WeatherColumn(
                    label: AppStrings.today,
                    summary: comparison.today,
                  ),
                ),
                Expanded(
                  child: _WeatherColumn(
                    label: AppStrings.yesterday,
                    summary: comparison.yesterday,
                  ),
                ),
                Expanded(
                  child: _WeatherColumn(
                    label: AppStrings.twoDaysAgo,
                    summary: comparison.twoDaysAgo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _comparisonText(highDiff),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _comparisonColor(highDiff),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _comparisonText(int diff) {
    if (diff > 0) {
      return '昨日より$diff°高い';
    }
    if (diff < 0) {
      return '昨日より${diff.abs()}°低い';
    }
    return '昨日と同じ';
  }

  Color _comparisonColor(int diff) {
    if (diff > 0) {
      return const Color(0xFFC65353);
    }
    if (diff < 0) {
      return const Color(0xFF326FA8);
    }
    return KisouTheme.softInk;
  }
}

class _WeatherColumn extends StatelessWidget {
  const _WeatherColumn({required this.label, required this.summary});

  final String label;
  final weather_model.WeatherSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(
          '${summary.tempHigh.round()}°',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: const Color(0xFFC65353)),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.tempLow.round()}°',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: const Color(0xFF326FA8)),
        ),
      ],
    );
  }
}
