import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String developmentBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String productionBaseUrl = String.fromEnvironment(
    'API_PRODUCTION_BASE_URL',
    defaultValue: '',
  );

  static const bool isDevelopment = environment == 'development';

  /// The active API base URL. Development builds hit [developmentBaseUrl];
  /// every other build uses [productionBaseUrl]. (Previously this was hard-wired
  /// to the development URL, so production/staging builds silently called
  /// localhost — audit B2.)
  static const String baseUrl =
      isDevelopment ? developmentBaseUrl : productionBaseUrl;

  // Double-gated: never in a release build (kReleaseMode), only in the dev
  // environment, and only when explicitly enabled — audit S3.
  static const bool showDevelopmentLogin =
      !kReleaseMode &&
      isDevelopment &&
      bool.fromEnvironment('SHOW_DEV_LOGIN', defaultValue: true);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
