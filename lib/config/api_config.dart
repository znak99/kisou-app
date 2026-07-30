import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String resolveApiBaseUrl({
  required String environment,
  required String developmentBaseUrl,
  required String productionBaseUrl,
  required bool releaseMode,
}) {
  if (environment != 'development' && environment != 'production') {
    throw StateError('APP_ENV must be either "development" or "production".');
  }
  if (releaseMode && environment != 'production') {
    throw StateError('Release builds require APP_ENV=production.');
  }

  final value = environment == 'development'
      ? developmentBaseUrl
      : productionBaseUrl;
  final uri = Uri.tryParse(value);
  final allowedScheme = environment == 'production'
      ? uri?.scheme == 'https'
      : uri?.scheme == 'http' || uri?.scheme == 'https';
  if (value.isEmpty ||
      value.trim() != value ||
      uri == null ||
      !uri.isAbsolute ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !allowedScheme) {
    final expectedScheme = environment == 'production' ? 'https' : 'http(s)';
    throw StateError(
      '$environment API URL must be an absolute $expectedScheme URL '
      'without credentials, query, or fragment.',
    );
  }
  return value;
}

void validateAppFlavor({
  required String environment,
  required String? flavor,
  required bool flavorRequired,
}) {
  if (!flavorRequired) {
    return;
  }
  final expectedFlavor = switch (environment) {
    'development' => 'dev',
    'production' => 'prod',
    _ => null,
  };
  if (flavor == null || flavor != expectedFlavor) {
    throw StateError(
      'Android flavor "$flavor" does not match APP_ENV="$environment".',
    );
  }
}

class ApiConfig {
  const ApiConfig._();

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
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

  /// Release builds reject development or malformed/insecure configuration at
  /// runtime. This is intentionally not an assert because asserts are stripped
  /// from production binaries.
  static final String baseUrl = resolveApiBaseUrl(
    environment: environment,
    developmentBaseUrl: developmentBaseUrl,
    productionBaseUrl: productionBaseUrl,
    releaseMode: kReleaseMode,
  );

  static const bool developmentFeaturesEnabled = kDebugMode && isDevelopment;

  // Triple-gated: debug mode, development environment, and explicit opt-in.
  static const bool showDevelopmentLogin =
      developmentFeaturesEnabled &&
      bool.fromEnvironment('SHOW_DEV_LOGIN', defaultValue: true);

  static void validateRuntime() {
    // Reading this value executes the release-safe validation above.
    baseUrl;
    validateAppFlavor(
      environment: environment,
      flavor: appFlavor,
      flavorRequired:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    );
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
