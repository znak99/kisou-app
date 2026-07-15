import 'package:dio/dio.dart';

import '../models/user.dart';

class UserService {
  const UserService(this._dio);

  final Dio _dio;

  Future<User> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    final data = response.data;
    if (data == null) {
      throw const UserServiceException('User response is empty.');
    }
    return User.fromJson(data);
  }

  Future<User> updateMe(UserUpdate update) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/me',
      data: update.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const UserServiceException('User update response is empty.');
    }
    return User.fromJson(data);
  }

  Future<User> resetData() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/reset-data',
    );
    final data = response.data;
    if (data == null) {
      throw const UserServiceException('Reset response is empty.');
    }
    return User.fromJson(data);
  }

  Future<void> deleteMe() async {
    await _dio.delete<void>('/users/me');
  }
}

class UserServiceException implements Exception {
  const UserServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
