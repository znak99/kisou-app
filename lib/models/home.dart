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
  final WeatherComparison weatherComparison;
}
