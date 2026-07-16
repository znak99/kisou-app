import 'package:dio/dio.dart';

import '../models/forecast.dart';

class ForecastService {
  const ForecastService(this._dio);

  final Dio _dio;

  Future<ForecastTomorrow> getTomorrow() async {
    final response = await _dio.get<Map<String, dynamic>>('/forecast/tomorrow');
    final data = response.data;
    if (data == null) {
      throw const ForecastServiceException('Forecast response is empty.');
    }
    return ForecastTomorrow.fromJson(data);
  }

  Future<ForecastOutlook> getOutlook({
    required String date,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/forecast/outlook',
      queryParameters: {
        'date': date,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    final data = response.data;
    if (data == null) {
      throw const ForecastServiceException('Outlook response is empty.');
    }
    return ForecastOutlook.fromJson(data);
  }
}

class ForecastServiceException implements Exception {
  const ForecastServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
