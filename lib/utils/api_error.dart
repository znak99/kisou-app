import 'package:dio/dio.dart';

import '../constants/app_strings.dart';

enum ApiErrorKind { offline, timeout, unauthorized, locationMissing, unknown }

ApiErrorKind classifyApiError(Object error) {
  if (error is! DioException) {
    return ApiErrorKind.unknown;
  }

  if (error.response?.statusCode == 401) {
    return ApiErrorKind.unauthorized;
  }

  if (_isLocationMissingError(error)) {
    return ApiErrorKind.locationMissing;
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => ApiErrorKind.timeout,
    DioExceptionType.connectionError => ApiErrorKind.offline,
    _ => ApiErrorKind.unknown,
  };
}

String apiErrorMessage(Object error) {
  return switch (classifyApiError(error)) {
    ApiErrorKind.offline => AppStrings.offlineError,
    ApiErrorKind.timeout => AppStrings.timeoutError,
    ApiErrorKind.locationMissing => AppStrings.locationMissing,
    ApiErrorKind.unauthorized => AppStrings.sessionExpired,
    ApiErrorKind.unknown => AppStrings.dataFetchFailed,
  };
}

bool _isLocationMissingError(DioException error) {
  final statusCode = error.response?.statusCode;
  final text = error.response?.data.toString().toLowerCase() ?? '';
  return statusCode == 400 &&
      (text.contains('location') ||
          text.contains('latitude') ||
          text.contains('longitude'));
}
