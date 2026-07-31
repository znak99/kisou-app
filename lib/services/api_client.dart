import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

class ApiClient {
  ApiClient({required AuthService authService, VoidCallback? onUnauthorized})
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await authService.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isAuthEndpoint = request.path.startsWith('/auth/');
          final alreadyRetried = request.extra['__retried'] == true;

          if (error.response?.statusCode == 401 &&
              !isAuthEndpoint &&
              !alreadyRetried) {
            // Access token likely expired: try to refresh once, then replay the
            // original request with the new token.
            final refreshed = await authService.refreshAccessToken();
            if (refreshed) {
              final newToken = await authService.readToken();
              request.extra['__retried'] = true;
              request.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch<dynamic>(request);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }

            // Refresh failed → the session is truly gone. Clear it and surface.
            await authService.clearTokens();
            await authService.clearOnboardingCompleted();
            if (request.extra['preserveAccountDeletionRecovery'] != true) {
              onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode && ApiConfig.developmentFeaturesEnabled) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      );
    }
  }

  final Dio dio;
}
