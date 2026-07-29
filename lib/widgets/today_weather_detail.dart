import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../models/weather.dart' as weather_model;

String _fmtTemp(double? value) => value == null ? '—' : '${value.round()}°';

/// Detailed weather card for today: high/low with feels-like, plus humidity,
/// wind, precipitation chance, and (in summer) the heat index.
class TodayWeatherDetail extends StatelessWidget {
  const TodayWeatherDetail({super.key, required this.today});

  final weather_model.WeatherSummary today;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final largeText = usesLargeText(context);
    final metrics = <(IconData, String, String)>[
      (
        Icons.water_drop_rounded,
        AppStrings.weatherHumidity,
        today.humidityAvg == null ? '—' : '${today.humidityAvg}%',
      ),
      (
        Icons.air_rounded,
        AppStrings.weatherWind,
        // Stored value is km/h (Open-Meteo default); Japan conventionally uses
        // m/s, so convert for display (audit B20).
        today.windSpeedAvg == null
            ? '—'
            : '${(today.windSpeedAvg! / 3.6).toStringAsFixed(1)} m/s',
      ),
      (
        Icons.umbrella_rounded,
        AppStrings.weatherPrecipitation,
        today.precipitationChanceMax == null
            ? '—'
            : '${today.precipitationChanceMax}%',
      ),
      if (today.wbgtMax != null)
        (
          Icons.thermostat_rounded,
          AppStrings.weatherWbgt,
          '${today.wbgtMax!.round()}',
        ),
    ];
    return ClayCard(
      // ~5% more compact card.
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.todayWeatherTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 11),
          if (largeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TemperatureRange(today: today),
                const SizedBox(height: KisouTheme.gapS),
                _FeelsLike(today: today, alignEnd: false),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TemperatureRange(today: today),
                const Spacer(),
                _FeelsLike(today: today, alignEnd: true),
              ],
            ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = largeText ? 2 : metrics.length;
              final spacing = KisouTheme.gapS;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: KisouTheme.gapL,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: itemWidth,
                      child: _Metric(
                        icon: metric.$1,
                        label: metric.$2,
                        value: metric.$3,
                        color: c.accent,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TemperatureRange extends StatelessWidget {
  const _TemperatureRange({required this.today});

  final weather_model.WeatherSummary today;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _fmtTemp(today.tempHigh),
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(color: c.warm, fontSize: 30),
        ),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            '/ ${_fmtTemp(today.tempLow)}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: c.cool, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _FeelsLike extends StatelessWidget {
  const _FeelsLike({required this.today, required this.alignEnd});

  final weather_model.WeatherSummary today;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.weatherFeelsLike,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          '${_fmtTemp(today.feelsLikeHigh)} / ${_fmtTemp(today.feelsLikeLow)}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 15),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
