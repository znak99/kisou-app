import 'package:dio/dio.dart';

import '../models/analysis.dart';

class AnalysisService {
  const AnalysisService(this._dio);

  final Dio _dio;

  Future<AnalysisResponse> getAnalysis() async {
    final response = await _dio.get<Map<String, dynamic>>('/analysis');
    final data = response.data;
    if (data == null) {
      throw const AnalysisServiceException('Analysis response is empty.');
    }
    return AnalysisResponse.fromJson(data);
  }
}

class AnalysisServiceException implements Exception {
  const AnalysisServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
