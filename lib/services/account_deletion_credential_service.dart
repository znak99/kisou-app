import 'package:dio/dio.dart';

import '../models/account_deletion_credentials.dart';

class AccountDeletionCredentialService {
  const AccountDeletionCredentialService(this._dio);

  static const path = '/users/me/account-deletion-credentials';

  final Dio _dio;

  Future<AccountDeletionCredentialDescriptor> getDescriptor() async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data;
    if (data == null) {
      throw const AccountDeletionCredentialServiceException(
        'Account deletion credential descriptor is empty.',
      );
    }
    return AccountDeletionCredentialDescriptor.fromJson(data);
  }

  Future<IssuedAccountDeletionCredential> rotate() async {
    final response = await _dio.post<Map<String, dynamic>>('$path/rotate');
    final data = response.data;
    if (data == null) {
      throw const AccountDeletionCredentialServiceException(
        'Account deletion credential response is empty.',
      );
    }
    return IssuedAccountDeletionCredential.fromJson(data);
  }
}

class AccountDeletionCredentialServiceException implements Exception {
  const AccountDeletionCredentialServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
