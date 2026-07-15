class WeatherSummary {
  const WeatherSummary({
    required this.tempHigh,
    required this.tempLow,
    required this.feelsLikeHigh,
    required this.feelsLikeLow,
    required this.humidityAvg,
    required this.windSpeedAvg,
    required this.precipitationChanceMax,
    required this.wbgtMax,
  });

  factory WeatherSummary.fromJson(Map<String, dynamic> json) {
    // All aggregates are nullable to match the API (Open-Meteo can return
    // all-null hourly arrays for the past edge of the window) — audit B21.
    return WeatherSummary(
      tempHigh: (json['temp_high'] as num?)?.toDouble(),
      tempLow: (json['temp_low'] as num?)?.toDouble(),
      feelsLikeHigh: (json['feels_like_high'] as num?)?.toDouble(),
      feelsLikeLow: (json['feels_like_low'] as num?)?.toDouble(),
      humidityAvg: json['humidity_avg'] as int?,
      windSpeedAvg: (json['wind_speed_avg'] as num?)?.toDouble(),
      precipitationChanceMax: json['precipitation_chance_max'] as int?,
      wbgtMax: (json['wbgt_max'] as num?)?.toDouble(),
    );
  }

  final double? tempHigh;
  final double? tempLow;
  final double? feelsLikeHigh;
  final double? feelsLikeLow;
  final int? humidityAvg;
  final double? windSpeedAvg;
  final int? precipitationChanceMax;
  final double? wbgtMax;
}

class WeatherComparison {
  const WeatherComparison({
    required this.today,
    required this.yesterday,
    required this.twoDaysAgo,
  });

  factory WeatherComparison.fromJson(Map<String, dynamic> json) {
    return WeatherComparison(
      today: WeatherSummary.fromJson(json['today'] as Map<String, dynamic>),
      yesterday: WeatherSummary.fromJson(
        json['yesterday'] as Map<String, dynamic>,
      ),
      twoDaysAgo: WeatherSummary.fromJson(
        json['two_days_ago'] as Map<String, dynamic>,
      ),
    );
  }

  final WeatherSummary today;
  final WeatherSummary yesterday;
  final WeatherSummary twoDaysAgo;
}
