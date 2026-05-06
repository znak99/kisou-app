import 'package:dio/dio.dart';

import '../models/home.dart';

class HomeService {
  const HomeService(this._dio);

  final Dio _dio;

  Future<HomeResponse> getHome() async {
    final response = await _dio.get<Map<String, dynamic>>('/home');
    final data = response.data;
    if (data == null) {
      throw const HomeServiceException('Home response is empty.');
    }
    return HomeResponse.fromJson(data);
  }
}

class HomeServiceException implements Exception {
  const HomeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
