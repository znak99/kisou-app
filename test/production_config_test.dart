import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/api_config.dart';
import 'package:kisou_app/services/auth_service.dart';

void main() {
  test(
    'production defines select only the secure production API',
    () {
      expect(ApiConfig.environment, 'production');
      expect(ApiConfig.baseUrl, 'https://kisou.znak99.cloud');
      expect(ApiConfig.developmentFeaturesEnabled, isFalse);
      expect(ApiConfig.showDevelopmentLogin, isFalse);
      expect(
        ApiConfig.secureStorageService,
        'flutter_secure_storage_service',
      );
    },
    skip: ApiConfig.environment != 'production',
  );

  test(
    'production defines disable development authentication',
    () {
      final service = AuthService();

      expect(
        () => service.loginWithDevelopmentExistingUser(dio: Dio()),
        throwsStateError,
      );
    },
    skip: ApiConfig.environment != 'production',
  );
}
