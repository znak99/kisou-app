import 'package:dio/dio.dart';

import '../models/feedback.dart';

class FeedbackService {
  const FeedbackService(this._dio);

  final Dio _dio;

  Future<FeedbackResponse> submitFeedback(FeedbackRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/feedback',
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const FeedbackServiceException('Feedback response is empty.');
    }
    return FeedbackResponse.fromJson(data);
  }

  Future<FeedbackTodayResponse> getTodayFeedback() async {
    final response = await _dio.get<Map<String, dynamic>>('/feedback/today');
    final data = response.data;
    if (data == null) {
      throw const FeedbackServiceException(
        'Feedback status response is empty.',
      );
    }
    return FeedbackTodayResponse.fromJson(data);
  }
}

class FeedbackServiceException implements Exception {
  const FeedbackServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
