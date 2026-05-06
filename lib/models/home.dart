import 'recommendation.dart';
import 'weather.dart';

class HomeResponse {
  const HomeResponse({
    required this.date,
    required this.recommendations,
    required this.weatherComparison,
  });

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    return HomeResponse(
      date: json['date'] as String,
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
  final List<RecommendationItem> recommendations;
  final WeatherComparison weatherComparison;
}
