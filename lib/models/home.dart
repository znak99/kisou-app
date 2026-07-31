import 'recommendation.dart';
import 'weather.dart';

class HomeResponse {
  const HomeResponse({
    required this.date,
    required this.feeling,
    required this.comfortMin,
    required this.comfortMax,
    required this.recommendations,
    required this.weatherComparison,
    this.recommendationContext,
    this.appliedTimeSlots,
    this.hoursAnalyzed = 0,
  });

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    return HomeResponse(
      date: json['date'] as String,
      feeling: json['feeling'] as String? ?? 'PERFECT',
      comfortMin: (json['comfort_min'] as num?)?.toDouble() ?? 0,
      comfortMax: (json['comfort_max'] as num?)?.toDouble() ?? 0,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((item) {
            return RecommendationItem.fromJson(item as Map<String, dynamic>);
          })
          .toList(growable: false),
      recommendationContext: _optionalNonEmptyString(
        json['recommendation_context'],
      ),
      appliedTimeSlots: _optionalStringList(json['applied_time_slots']),
      hoursAnalyzed: _optionalHoursAnalyzed(json['hours_analyzed']),
      weatherComparison: WeatherComparison.fromJson(
        json['weather_comparison'] as Map<String, dynamic>,
      ),
    );
  }

  final String date;
  final String feeling;
  final double comfortMin;
  final double comfortMax;
  final List<RecommendationItem> recommendations;
  final String? recommendationContext;
  final List<String>? appliedTimeSlots;
  final int hoursAnalyzed;
  final WeatherComparison weatherComparison;
}

String? _optionalNonEmptyString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

List<String>? _optionalStringList(Object? value) {
  if (value is! List) {
    return null;
  }
  final strings = value.whereType<String>().toList(growable: false);
  return strings.isEmpty ? null : strings;
}

int _optionalHoursAnalyzed(Object? value) {
  return value is int && value >= 1 && value <= 24 ? value : 0;
}
