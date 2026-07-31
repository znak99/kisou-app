import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/services/api_client.dart';
import 'package:kisou_app/services/auth_service.dart';

void main() {
  test(
    'deletion 401 clears tokens without firing the global account-switch callback',
    () async {
      final auth = _UnauthorizedAuthService();
      var unauthorizedCallbacks = 0;
      final dio = ApiClient(
        authService: auth,
        onUnauthorized: () => unauthorizedCallbacks++,
      ).dio;
      dio.httpClientAdapter = _Always401Adapter();

      await expectLater(
        dio.delete<void>(
          '/users/me',
          options: Options(extra: {'preserveAccountDeletionRecovery': true}),
        ),
        throwsA(isA<DioException>()),
      );

      expect(auth.clearTokenCalls, 1);
      expect(auth.clearOnboardingCalls, 1);
      expect(auth.onboardingCompleted, isFalse);
      expect(unauthorizedCallbacks, 0);

      auth.token = 'another-token';
      await expectLater(dio.get<void>('/home'), throwsA(isA<DioException>()));
      expect(unauthorizedCallbacks, 1);
    },
  );

  test('push cleanup 401 preserves auth for the outer cleanup retry', () async {
    final auth = _UnauthorizedAuthService();
    var unauthorizedCallbacks = 0;
    final dio = ApiClient(
      authService: auth,
      onUnauthorized: () => unauthorizedCallbacks++,
    ).dio;
    dio.httpClientAdapter = _Always401Adapter();

    await expectLater(
      dio.post<void>(
        '/push/devices/unregister',
        options: Options(extra: {'suppressAuthRecovery': true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(auth.clearTokenCalls, 0);
    expect(auth.clearOnboardingCalls, 0);
    expect(auth.token, 'access-token');
    expect(auth.onboardingCompleted, isTrue);
    expect(unauthorizedCallbacks, 0);
  });
}

class _Always401Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"detail":"unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnauthorizedAuthService extends AuthService {
  String? token = 'access-token';
  var clearTokenCalls = 0;
  var clearOnboardingCalls = 0;
  var onboardingCompleted = true;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<bool> refreshAccessToken() async => false;

  @override
  Future<void> clearTokens() async {
    clearTokenCalls++;
    token = null;
  }

  @override
  Future<void> clearOnboardingCompleted() async {
    clearOnboardingCalls++;
    onboardingCompleted = false;
  }
}
