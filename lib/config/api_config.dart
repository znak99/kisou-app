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

  static const String baseUrl = developmentBaseUrl;
  static const bool isDevelopment = environment == 'development';
  static const bool showDevelopmentLogin =
      isDevelopment &&
      bool.fromEnvironment('SHOW_DEV_LOGIN', defaultValue: true);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
