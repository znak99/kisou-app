import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/api_config.dart';
import '../models/auth.dart';
import 'ad_reward_operation_store.dart';
import 'push_local_metadata.dart';

enum AuthLoginProvider {
  apple('apple'),
  google('google');

  const AuthLoginProvider(this.apiValue);

  final String apiValue;
}

enum LocalCleanupTransition {
  logout,
  accountDeletionRequested,
  accountDeletion,
  accountSwitch,
  unconfirmedAccountDiscard,
}

class AuthService {
  AuthService({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? preferencesFactory,
    AdRewardOperationStore? adRewardOperationStore,
    bool developmentAuthEnabled = ApiConfig.developmentFeaturesEnabled,
  }) : _storage =
           storage ??
           FlutterSecureStorage(
             iOptions: IOSOptions(accountName: ApiConfig.secureStorageService),
           ),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance,
       _adRewardOperationStore =
           adRewardOperationStore ?? AdRewardOperationStore(storage: storage),
       _developmentAuthEnabled = developmentAuthEnabled;

  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  // The server-issued anonymous secret. Stored in the (encrypted) secure
  // storage — never SharedPreferences — so it isn't exposed via Android backup.
  static const String _deviceSecretKey = 'device_secret';
  static const String _hasLaunchedBeforeKey = 'has_launched_before';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _localCleanupTransitionKey =
      'local_cleanup_transition_v1';
  static const String _accountDeletionRequestMarkerVersion = 'v2';

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _preferencesFactory;
  final AdRewardOperationStore _adRewardOperationStore;
  final bool _developmentAuthEnabled;
  Future<void>? _googleInitializeFuture;
  Future<bool>? _refreshInFlight;
  int _developmentLoginSequence = 0;

  Future<void> clearKeychainOnFirstLaunch() async {
    final preferences = await _preferencesFactory();
    final hasLaunchedBefore =
        preferences.getBool(_hasLaunchedBeforeKey) ?? false;
    if (hasLaunchedBefore) {
      return;
    }

    // iOS Keychain survives reinstall. Clear every known identity-owned key
    // individually so the install-scoped push UUID/revision/cleanup marker is
    // never erased before accountSwitch can tombstone the old registration and
    // delete its token/FID. Unknown keys are inert because no code reads them.
    for (final key in const [
      _tokenKey,
      _refreshTokenKey,
      _deviceSecretKey,
      _localCleanupTransitionKey,
      AdRewardOperationStore.storageKey,
    ]) {
      await _storage.delete(key: key);
    }
    await preferences.setBool(_hasLaunchedBeforeKey, true);
  }

  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() {
    return _storage.delete(key: _tokenKey);
  }

  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  /// Persists the access + refresh tokens (and the anonymous secret when the
  /// server issued a new one) from a login/anonymous response.
  Future<void> _saveSession(LoginResponse response) async {
    await _storage.write(key: _tokenKey, value: response.accessToken);
    await _storage.write(key: _refreshTokenKey, value: response.refreshToken);
    final secret = response.deviceSecret;
    if (secret != null && secret.isNotEmpty) {
      await _storage.write(key: _deviceSecretKey, value: secret);
    }
  }

  /// Clears the access + refresh tokens (session), keeping the anonymous
  /// device_secret so the same anonymous account can be restored on next launch.
  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> isOnboardingCompleted() async {
    final preferences = await _preferencesFactory();
    return preferences.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool isCompleted) async {
    final preferences = await _preferencesFactory();
    await preferences.setBool(_onboardingCompletedKey, isCompleted);
  }

  Future<void> clearOnboardingCompleted() async {
    final preferences = await _preferencesFactory();
    await preferences.remove(_onboardingCompletedKey);
  }

  Future<void> clearPendingAdRewardOperation() {
    return _adRewardOperationStore.closeWritesAndClear();
  }

  Future<LocalCleanupTransition?> readLocalCleanupTransition() async {
    final value = await _storage.read(key: _localCleanupTransitionKey);
    for (final transition in const [
      LocalCleanupTransition.accountDeletionRequested,
      LocalCleanupTransition.accountDeletion,
    ]) {
      if (value?.startsWith(
            '${transition.name}:$_accountDeletionRequestMarkerVersion:',
          ) ==
          true) {
        return transition;
      }
    }
    for (final transition in LocalCleanupTransition.values) {
      if (transition.name == value) {
        return transition;
      }
    }
    // Treat an unknown marker as an interrupted account switch. Failing
    // closed prevents a future schema mismatch from exposing account data.
    return value == null ? null : LocalCleanupTransition.accountSwitch;
  }

  Future<void> markLocalCleanupTransition(LocalCleanupTransition transition) {
    return _storage.write(
      key: _localCleanupTransitionKey,
      value: transition.name,
    );
  }

  /// Atomically persists both the crash-recovery phase and the request UUID in
  /// one secure-storage value before DELETE /users/me can be sent.
  Future<void> markAccountDeletionRequested(String idempotencyKey) {
    return _markAccountDeletionWithKey(
      LocalCleanupTransition.accountDeletionRequested,
      idempotencyKey,
    );
  }

  /// Keeps the confirmed receipt key in the same crash-recovery record until
  /// every account-bound local store has been erased successfully.
  Future<void> markAccountDeletionConfirmed(String idempotencyKey) {
    return _markAccountDeletionWithKey(
      LocalCleanupTransition.accountDeletion,
      idempotencyKey,
    );
  }

  Future<void> _markAccountDeletionWithKey(
    LocalCleanupTransition transition,
    String idempotencyKey,
  ) {
    if (!_uuidPattern.hasMatch(idempotencyKey)) {
      throw const FormatException('Invalid account-deletion idempotency key.');
    }
    return _storage.write(
      key: _localCleanupTransitionKey,
      value:
          '${transition.name}:'
          '$_accountDeletionRequestMarkerVersion:$idempotencyKey',
    );
  }

  /// Returns null for the legacy marker or a damaged value. The transition
  /// itself remains accountDeletionRequested, so the app stays fail-closed.
  Future<String?> readAccountDeletionRequestIdempotencyKey() async {
    final value = await _storage.read(key: _localCleanupTransitionKey);
    if (value == null) {
      return null;
    }
    for (final transition in const [
      LocalCleanupTransition.accountDeletionRequested,
      LocalCleanupTransition.accountDeletion,
    ]) {
      final prefix =
          '${transition.name}:$_accountDeletionRequestMarkerVersion:';
      if (value.startsWith(prefix)) {
        final key = value.substring(prefix.length);
        return _uuidPattern.hasMatch(key) ? key : null;
      }
    }
    return null;
  }

  Future<void> clearLocalCleanupTransition() {
    return _storage.delete(key: _localCleanupTransitionKey);
  }

  /// Removes every local identity credential and preference after confirmed
  /// server deletion or an explicit unconfirmed local-only discard.
  ///
  /// This intentionally differs from logout/account switch, which keep the
  /// anonymous restoration secret so the same guest can be restored.
  Future<void> clearLocalAccountData() async {
    // Delete only auth-owned keys. The transition marker must survive until
    // every other account-bound store has completed cleanup successfully.
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _deviceSecretKey);
    await clearPendingAdRewardOperation();
    final preferences = await _preferencesFactory();
    // OS permission history and consume-once delivery receipts are
    // installation-scoped, not account data. Preserve them across the broad
    // preference wipe so an old delivery cannot route twice for a later user.
    final pushPromptCount = preferences.getInt(
      pushPermissionPromptCountStorageKey,
    );
    final pushDeliveryReceipts = preferences.getString(
      pushDeliveryReceiptStorageKey,
    );
    await preferences.clear();
    if (pushPromptCount != null) {
      await preferences.setInt(
        pushPermissionPromptCountStorageKey,
        pushPromptCount,
      );
    }
    if (pushDeliveryReceipts != null) {
      await preferences.setString(
        pushDeliveryReceiptStorageKey,
        pushDeliveryReceipts,
      );
    }
  }

  Future<String> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AuthException('Apple identity token is empty.');
    }
    return identityToken;
  }

  Future<String> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google ID token is empty.');
    }
    return idToken;
  }

  Future<bool> loginWithServer({
    required Dio dio,
    required AuthLoginProvider provider,
    required String token,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'provider': provider.apiValue, 'token': token},
    );
    final data = response.data;
    if (data == null) {
      throw const AuthException('Login response is empty.');
    }

    final loginResponse = LoginResponse.fromJson(data);
    await _saveSession(loginResponse);
    return loginResponse.isNewUser;
  }

  /// Issues (or restores) an anonymous account. On first launch there is no
  /// stored secret, so the server creates an account and returns a device_secret
  /// which we persist; subsequent launches present that secret to restore the
  /// same account. If the stored secret is rejected (e.g. the server was reset),
  /// we discard it and create a fresh account.
  Future<bool> loginAnonymous({required Dio dio}) async {
    final secret = await _storage.read(key: _deviceSecretKey);
    try {
      return await _postAnonymous(dio: dio, deviceSecret: secret);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && secret != null) {
        await _storage.delete(key: _deviceSecretKey);
        return _postAnonymous(dio: dio, deviceSecret: null);
      }
      rethrow;
    }
  }

  /// Restores only the exact anonymous account already bound to this device.
  ///
  /// Account-deletion recovery must never fall back to creating a fresh guest:
  /// doing so could send the old request UUID while authenticated as a
  /// different account.
  Future<bool> restoreAnonymousSessionForDeletion({required Dio dio}) async {
    final secret = await _storage.read(key: _deviceSecretKey);
    if (secret == null || secret.isEmpty) {
      return false;
    }
    try {
      await _postAnonymous(dio: dio, deviceSecret: secret);
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _postAnonymous({
    required Dio dio,
    required String? deviceSecret,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/anonymous',
      data: deviceSecret == null
          ? <String, dynamic>{}
          : {'device_secret': deviceSecret},
    );
    final data = response.data;
    if (data == null) {
      throw const AuthException('Anonymous login response is empty.');
    }
    final loginResponse = LoginResponse.fromJson(data);
    await _saveSession(loginResponse);
    return loginResponse.isNewUser;
  }

  /// Exchanges the stored refresh token for a fresh access + refresh token.
  /// De-duplicated so concurrent 401s trigger a single refresh call. Uses a
  /// bare Dio (no auth interceptor) to avoid recursion. Returns false when
  /// there is no refresh token or the server rejects it.
  Future<bool> refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ),
    );
    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data == null) {
        return false;
      }
      await saveToken((data['access_token'] ?? data['accessToken']) as String);
      await _storage.write(
        key: _refreshTokenKey,
        value: (data['refresh_token'] ?? data['refreshToken']) as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  /// Best-effort server-side logout: local logout must still work offline.
  Future<void> logoutServer({required Dio dio}) async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }
    try {
      await dio.post<void>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException {
      // The caller clears local credentials and account-bound device data.
    }
  }

  /// Links the current (anonymous) account to a verified social identity.
  Future<void> linkAccount({
    required Dio dio,
    required AuthLoginProvider provider,
    required String token,
  }) async {
    await dio.post<Map<String, dynamic>>(
      '/auth/link',
      data: {'provider': provider.apiValue, 'token': token},
    );
    // The anonymous identity is invalid after a successful provider link.
    await _storage.delete(key: _deviceSecretKey);
  }

  Future<void> linkWithApple({required Dio dio}) async {
    final token = await signInWithApple();
    await linkAccount(
      dio: dio,
      provider: AuthLoginProvider.apple,
      token: token,
    );
  }

  Future<void> linkWithGoogle({required Dio dio}) async {
    final token = await signInWithGoogle();
    await linkAccount(
      dio: dio,
      provider: AuthLoginProvider.google,
      token: token,
    );
  }

  Future<void> linkWithDevelopment({required Dio dio}) {
    _requireDevelopmentAuth();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return linkAccount(
      dio: dio,
      provider: AuthLoginProvider.google,
      token: 'dev-link-$timestamp',
    );
  }

  Future<bool> loginWithApple({required Dio dio}) async {
    final token = await signInWithApple();
    return loginWithServer(
      dio: dio,
      provider: AuthLoginProvider.apple,
      token: token,
    );
  }

  Future<bool> loginWithGoogle({required Dio dio}) async {
    final token = await signInWithGoogle();
    return loginWithServer(
      dio: dio,
      provider: AuthLoginProvider.google,
      token: token,
    );
  }

  Future<bool> loginWithDevelopmentExistingUser({required Dio dio}) {
    _requireDevelopmentAuth();
    return loginWithServer(
      dio: dio,
      provider: AuthLoginProvider.google,
      token: 'dev-test-user',
    );
  }

  Future<bool> loginWithDevelopmentNewUser({required Dio dio}) {
    _requireDevelopmentAuth();
    _developmentLoginSequence += 1;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return loginWithServer(
      dio: dio,
      provider: AuthLoginProvider.google,
      token: 'dev-user-$timestamp-$_developmentLoginSequence',
    );
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitializeFuture ??= GoogleSignIn.instance.initialize();
  }

  void _requireDevelopmentAuth() {
    if (!_developmentAuthEnabled) {
      throw StateError('Development authentication is disabled in this build.');
    }
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
