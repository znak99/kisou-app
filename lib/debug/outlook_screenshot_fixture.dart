import '../models/forecast.dart';
import '../models/recommendation.dart';
import '../models/weather.dart';

ForecastOutlook buildOutlookScreenshotFixture({required String date}) {
  return ForecastOutlook(
    date: date,
    mode: 'forecast',
    feeling: 'VERY_HOT',
    comfortMin: 26,
    comfortMax: 29,
    recommendations: const [
      RecommendationItem(
        rank: 1,
        top: 'SHORT_SLEEVE',
        bottom: 'SKIRT',
        outer: null,
      ),
    ],
    weather: const WeatherSummary(
      tempHigh: 29,
      tempLow: 26,
      feelsLikeHigh: 31,
      feelsLikeLow: 28,
      humidityAvg: 74,
      windSpeedAvg: 0.7,
      precipitationChanceMax: 73,
      wbgtMax: 24,
    ),
    climate: null,
  );
}
