import 'package:dio/dio.dart';

import '../models/account_deletion_status.dart';
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

  Future<void> deleteMe({required String idempotencyKey}) async {
    await _dio.delete<void>(
      '/users/me',
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        // The deletion coordinator owns this transition. A 401 may mean the
        // DELETE committed and its response was lost, so the global auth
        // callback must not overwrite the receipt-recovery marker.
        extra: {'preserveAccountDeletionRecovery': true},
      ),
    );
  }

  /// Returns null only when the server has no live completion receipt for the
  /// supplied key. Network, parsing, and server failures remain errors so a
  /// caller can never mistake an unknown result for completed deletion.
  Future<AccountDeletionStatus?> getDeletionStatus({
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/account-deletion/status',
        data: {'idempotency_key': idempotencyKey},
      );
      final data = response.data;
      if (data == null) {
        throw const UserServiceException(
          'Account deletion status response is empty.',
        );
      }
      return AccountDeletionStatus.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

class UserServiceException implements Exception {
  const UserServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
