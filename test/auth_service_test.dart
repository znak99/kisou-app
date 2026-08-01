import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/auth.dart';
import 'package:kisou_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses snake case new user flag from login response', () {
    final response = LoginResponse.fromJson({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'token_type': 'bearer',
      'is_new_user': true,
    });

    expect(response.accessToken, 'access-token');
    expect(response.refreshToken, 'refresh-token');
    expect(response.tokenType, 'bearer');
    expect(response.isNewUser, isTrue);
  });

  test(
    'clears secure storage on first launch and stores launch flag',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'jwt_token': 'stale-token',
        'refresh_token': 'stale-refresh-token',
        'device_secret': 'stale-device-secret',
        'local_cleanup_transition_v1': 'accountSwitch',
        'ad_reward_operation_v1': 'stale-operation',
      });

      const storage = FlutterSecureStorage();
      final service = AuthService(storage: storage);
      await service.clearKeychainOnFirstLaunch();

      expect(await storage.readAll(), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('has_launched_before'), isTrue);
    },
  );

  test('keeps secure storage after first launch flag exists', () async {
    SharedPreferences.setMockInitialValues({'has_launched_before': true});
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'saved-token'});

    final service = AuthService();
    await service.clearKeychainOnFirstLaunch();

    expect(await service.readToken(), 'saved-token');
  });

  test(
    'does not mark first launch complete when secure deletion fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = AuthService(storage: const _FailingDeleteAllStorage());

      await expectLater(service.clearKeychainOnFirstLaunch(), throwsStateError);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('has_launched_before'), isNull);
    },
  );

  test('stores onboarding completed flag', () async {
    SharedPreferences.setMockInitialValues({});

    final service = AuthService();
    expect(await service.isOnboardingCompleted(), isFalse);

    await service.setOnboardingCompleted(true);
    expect(await service.isOnboardingCompleted(), isTrue);

    await service.setOnboardingCompleted(false);
    expect(await service.isOnboardingCompleted(), isFalse);
  });

  test(
    'session-only cleanup preserves the anonymous restoration secret',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'jwt_token': 'access-token',
        'refresh_token': 'refresh-token',
        'device_secret': 'same-guest-secret',
      });
      const storage = FlutterSecureStorage();
      final service = AuthService(storage: storage);

      await service.clearTokens();

      expect(await storage.readAll(), {'device_secret': 'same-guest-secret'});
    },
  );

  test(
    'account deletion clears auth keys without erasing the transition marker',
    () async {
      SharedPreferences.setMockInitialValues({
        'has_launched_before': true,
        'onboarding_completed': true,
        'theme_mode': 'dark',
        'outlook_quota_date': '2026-07-31',
      });
      FlutterSecureStorage.setMockInitialValues({
        'jwt_token': 'access-token',
        'refresh_token': 'refresh-token',
        'device_secret': 'anonymous-secret',
        'local_cleanup_transition_v1': 'accountDeletion',
        'ad_reward_operation_v1': 'old-account-operation',
      });

      const storage = FlutterSecureStorage();
      final service = AuthService(storage: storage);
      await service.clearLocalAccountData();

      expect(await storage.readAll(), {
        'local_cleanup_transition_v1': 'accountDeletion',
      });
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    },
  );

  test('round-trips the durable local cleanup transition', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = AuthService();

    expect(await service.readLocalCleanupTransition(), isNull);
    await service.markLocalCleanupTransition(
      LocalCleanupTransition.accountSwitch,
    );
    expect(
      await service.readLocalCleanupTransition(),
      LocalCleanupTransition.accountSwitch,
    );
    await service.markLocalCleanupTransition(
      LocalCleanupTransition.unconfirmedAccountDiscard,
    );
    expect(
      await service.readLocalCleanupTransition(),
      LocalCleanupTransition.unconfirmedAccountDiscard,
    );
    await service.clearLocalCleanupTransition();
    expect(await service.readLocalCleanupTransition(), isNull);
  });

  test(
    'atomically stores deletion phase and canonical UUID capability',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final service = AuthService(storage: storage);
      const key = '11111111-1111-4111-8111-111111111111';

      await service.markAccountDeletionRequested(key);

      expect(
        await storage.read(key: 'local_cleanup_transition_v1'),
        'accountDeletionRequested:v2:$key',
      );
      expect(
        await service.readLocalCleanupTransition(),
        LocalCleanupTransition.accountDeletionRequested,
      );
      expect(await service.readAccountDeletionRequestIdempotencyKey(), key);

      await service.markAccountDeletionConfirmed(key);
      expect(
        await storage.read(key: 'local_cleanup_transition_v1'),
        'accountDeletion:v2:$key',
      );
    },
  );

  test('rejects a non-v4 or non-canonical deletion capability', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final service = AuthService(storage: storage);

    expect(
      () => service.markAccountDeletionRequested(
        'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
      ),
      throwsFormatException,
    );
    expect(
      () => service.markAccountDeletionRequested(
        '11111111-1111-1111-8111-111111111111',
      ),
      throwsFormatException,
    );
    expect(await storage.read(key: 'local_cleanup_transition_v1'), isNull);
  });

  test(
    'strict deletion restore never creates a replacement anonymous account',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'device_secret': 'same-account-secret',
      });
      const storage = FlutterSecureStorage();
      final service = AuthService(storage: storage);
      final requests = <Map<String, dynamic>>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(
              Map<String, dynamic>.from(options.data as Map<String, dynamic>),
            );
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 401,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      expect(
        await service.restoreAnonymousSessionForDeletion(dio: dio),
        isFalse,
      );

      expect(requests, [
        {'device_secret': 'same-account-secret'},
      ]);
      expect(await storage.read(key: 'device_secret'), 'same-account-secret');
    },
  );

  test(
    'successful account linking removes the obsolete anonymous secret',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'device_secret': 'anonymous-secret',
      });
      const storage = FlutterSecureStorage();
      final service = AuthService(storage: storage);
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response<void>(requestOptions: options));
          },
        ),
      );

      await service.linkAccount(
        dio: dio,
        provider: AuthLoginProvider.apple,
        token: 'identity-token',
      );

      expect(await storage.read(key: 'device_secret'), isNull);
    },
  );

  test('development existing login sends fixed token', () async {
    final tokens = <String>[];
    final dio = _createLoginDio(tokens, isNewUser: false);

    final service = AuthService();
    final isNewUser = await service.loginWithDevelopmentExistingUser(dio: dio);

    expect(isNewUser, isFalse);
    expect(tokens, ['dev-test-user']);
  });

  test('development new login sends unique tokens', () async {
    final tokens = <String>[];
    final dio = _createLoginDio(tokens, isNewUser: true);

    final service = AuthService();
    final firstIsNewUser = await service.loginWithDevelopmentNewUser(dio: dio);
    final secondIsNewUser = await service.loginWithDevelopmentNewUser(dio: dio);

    expect(firstIsNewUser, isTrue);
    expect(secondIsNewUser, isTrue);
    expect(tokens, hasLength(2));
    expect(tokens[0], startsWith('dev-user-'));
    expect(tokens[1], startsWith('dev-user-'));
    expect(tokens[0], isNot(tokens[1]));
  });

  test('development auth methods fail before a request when disabled', () {
    final service = AuthService(developmentAuthEnabled: false);
    final dio = Dio();

    expect(
      () => service.loginWithDevelopmentExistingUser(dio: dio),
      throwsStateError,
    );
    expect(
      () => service.loginWithDevelopmentNewUser(dio: dio),
      throwsStateError,
    );
    expect(() => service.linkWithDevelopment(dio: dio), throwsStateError);
  });
}

class _FailingDeleteAllStorage extends FlutterSecureStorage {
  const _FailingDeleteAllStorage();

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    return Future<void>.error(StateError('secure deletion failed'));
  }
}

Dio _createLoginDio(List<String> tokens, {required bool isNewUser}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final data = options.data as Map<String, dynamic>;
        tokens.add(data['token'] as String);
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'access_token': 'access-token-${tokens.length}',
              'refresh_token': 'refresh-token-${tokens.length}',
              'token_type': 'bearer',
              'is_new_user': isNewUser,
            },
          ),
        );
      },
    ),
  );
  return dio;
}
