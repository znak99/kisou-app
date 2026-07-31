import 'package:dio/dio.dart';

import '../models/widget_recommendation.dart';

abstract interface class WidgetRecommendationSource {
  Future<WidgetRecommendation> getToday();
}

class WidgetRecommendationService implements WidgetRecommendationSource {
  const WidgetRecommendationService(this._dio);

  final Dio _dio;

  @override
  Future<WidgetRecommendation> getToday() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/widget/today',
      options: Options(
        headers: const {
          // The endpoint is account-personalized. The server also responds
          // no-store, while this request directive protects intermediary
          // configurations that might otherwise reuse a prior account's body.
          'Cache-Control': 'no-cache, no-store',
          'Pragma': 'no-cache',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw const FormatException('Unexpected widget response status.');
    }
    final data = response.data;
    if (data == null) {
      throw const FormatException('Widget response is empty.');
    }
    return WidgetRecommendation.fromJson(data);
  }
}
