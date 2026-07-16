import 'recommendation.dart';
import 'weather.dart';

/// One row of the compact multi-day strip under the tomorrow card.
class DailyOutlook {
  const DailyOutlook({
    required this.date,
    required this.tempHigh,
    required this.tempLow,
    required this.precipitationChanceMax,
  });

  factory DailyOutlook.fromJson(Map<String, dynamic> json) {
    return DailyOutlook(
      date: json['date'] as String,
      tempHigh: (json['temp_high'] as num?)?.toDouble(),
      tempLow: (json['temp_low'] as num?)?.toDouble(),
      precipitationChanceMax: json['precipitation_chance_max'] as int?,
    );
  }

  final String date;
  final double? tempHigh;
  final double? tempLow;
  final int? precipitationChanceMax;
}

/// GET /forecast/tomorrow — tomorrow's recommendation plus today's summary
/// for the "compared to today" line.
class ForecastTomorrow {
  const ForecastTomorrow({
    required this.date,
    required this.feeling,
    required this.comfortMin,
    required this.comfortMax,
    required this.recommendations,
    required this.weather,
    required this.todayWeather,
    required this.upcoming,
  });

  factory ForecastTomorrow.fromJson(Map<String, dynamic> json) {
    return ForecastTomorrow(
      date: json['date'] as String,
      feeling: json['feeling'] as String? ?? 'PERFECT',
      comfortMin: (json['comfort_min'] as num?)?.toDouble() ?? 0,
      comfortMax: (json['comfort_max'] as num?)?.toDouble() ?? 0,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((item) {
            return RecommendationItem.fromJson(item as Map<String, dynamic>);
          })
          .toList(growable: false),
      weather: WeatherSummary.fromJson(
        json['weather'] as Map<String, dynamic>,
      ),
      todayWeather: WeatherSummary.fromJson(
        json['today_weather'] as Map<String, dynamic>,
      ),
      upcoming: (json['upcoming'] as List<dynamic>? ?? const [])
          .map((item) => DailyOutlook.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String date;
  final String feeling;
  final double comfortMin;
  final double comfortMax;
  final List<RecommendationItem> recommendations;
  final WeatherSummary weather;
  final WeatherSummary todayWeather;
  final List<DailyOutlook> upcoming;
}

/// Past-years temperature spread behind a climatology estimate. The averages
/// are the headline numbers (what weather services call 平年値); the min/max
/// spread is secondary context.
class ClimateStats {
  const ClimateStats({
    required this.tempLowAvg,
    required this.tempLowMin,
    required this.tempLowMax,
    required this.tempHighAvg,
    required this.tempHighMin,
    required this.tempHighMax,
    required this.yearsUsed,
    required this.sampleDays,
  });

  factory ClimateStats.fromJson(Map<String, dynamic> json) {
    return ClimateStats(
      tempLowAvg: (json['temp_low_avg'] as num).toDouble(),
      tempLowMin: (json['temp_low_min'] as num).toDouble(),
      tempLowMax: (json['temp_low_max'] as num).toDouble(),
      tempHighAvg: (json['temp_high_avg'] as num).toDouble(),
      tempHighMin: (json['temp_high_min'] as num).toDouble(),
      tempHighMax: (json['temp_high_max'] as num).toDouble(),
      yearsUsed: json['years_used'] as int,
      sampleDays: json['sample_days'] as int,
    );
  }

  final double tempLowAvg;
  final double tempLowMin;
  final double tempLowMax;
  final double tempHighAvg;
  final double tempHighMin;
  final double tempHighMax;
  final int yearsUsed;
  final int sampleDays;
}

/// GET /forecast/outlook — recommendation for an arbitrary future date/place.
/// `forecast` mode carries [weather]; `climatology` mode carries [climate].
class ForecastOutlook {
  const ForecastOutlook({
    required this.date,
    required this.mode,
    required this.feeling,
    required this.comfortMin,
    required this.comfortMax,
    required this.recommendations,
    required this.weather,
    required this.climate,
  });

  factory ForecastOutlook.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'] as Map<String, dynamic>?;
    final climate = json['climate'] as Map<String, dynamic>?;
    return ForecastOutlook(
      date: json['date'] as String,
      mode: json['mode'] as String,
      feeling: json['feeling'] as String? ?? 'PERFECT',
      comfortMin: (json['comfort_min'] as num?)?.toDouble() ?? 0,
      comfortMax: (json['comfort_max'] as num?)?.toDouble() ?? 0,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((item) {
            return RecommendationItem.fromJson(item as Map<String, dynamic>);
          })
          .toList(growable: false),
      weather: weather == null ? null : WeatherSummary.fromJson(weather),
      climate: climate == null ? null : ClimateStats.fromJson(climate),
    );
  }

  final String date;
  final String mode;
  final String feeling;
  final double comfortMin;
  final double comfortMax;
  final List<RecommendationItem> recommendations;
  final WeatherSummary? weather;
  final ClimateStats? climate;

  bool get isClimatology => mode == 'climatology';
}
