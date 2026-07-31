import 'package:dio/dio.dart';

import '../models/forecast.dart';
import '../models/outlook_quota.dart';

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

  Future<ForecastOutlookResponse> getOutlook({
    required String date,
    required double latitude,
    required double longitude,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/forecast/outlook',
      data: {'date': date, 'latitude': latitude, 'longitude': longitude},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final data = response.data;
    if (data == null) {
      throw const ForecastServiceException('Outlook response is empty.');
    }
    final quotaJson = data['quota'];
    final quotaConsumed = data['quota_consumed'];
    if (quotaJson is! Map<String, dynamic> ||
        (quotaConsumed != 'free' && quotaConsumed != 'reward')) {
      throw const ForecastServiceException(
        'Outlook response has invalid quota data.',
      );
    }
    return ForecastOutlookResponse(
      outlook: ForecastOutlook.fromJson(data),
      quotaConsumed: quotaConsumed as String,
      quota: OutlookQuota.fromJson(quotaJson),
    );
  }

  Future<OutlookQuota> getOutlookQuota() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/forecast/outlook/quota',
    );
    final data = response.data;
    if (data == null) {
      throw const ForecastServiceException('Outlook quota response is empty.');
    }
    return OutlookQuota.fromJson(data);
  }
}

class ForecastOutlookResponse {
  const ForecastOutlookResponse({
    required this.outlook,
    required this.quotaConsumed,
    required this.quota,
  });

  final ForecastOutlook outlook;
  final String quotaConsumed;
  final OutlookQuota quota;
}

class ForecastServiceException implements Exception {
  const ForecastServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
