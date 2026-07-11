import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/auth.dart';

enum AuthLoginProvider {
  apple('apple'),
  google('google');

  const AuthLoginProvider(this.apiValue);

  final String apiValue;
}

class AuthService {
  AuthService({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  static const String _tokenKey = 'jwt_token';
  static const String _hasLaunchedBeforeKey = 'has_launched_before';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _deviceIdKey = 'device_id';

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _preferencesFactory;
  Future<void>? _googleInitializeFuture;
  int _developmentLoginSequence = 0;

  Future<void> clearKeychainOnFirstLaunch() async {
    final preferences = await _preferencesFactory();
    final hasLaunchedBefore =
        preferences.getBool(_hasLaunchedBeforeKey) ?? false;
    if (hasLaunchedBefore) {
      return;
    }

    await _storage.deleteAll();
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

  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
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
    await saveToken(loginResponse.accessToken);
    return loginResponse.isNewUser;
  }

  /// Ensures a stable per-device id, generating and persisting one on first use.
  Future<String> getOrCreateDeviceId() async {
    final preferences = await _preferencesFactory();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.length >= 8) {
      return existing;
    }
    final random = Random.secure();
    final deviceId = List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await preferences.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  /// Issues (or reuses) an anonymous account for this device. No sign-in needed.
  Future<bool> loginAnonymous({required Dio dio}) async {
    final deviceId = await getOrCreateDeviceId();
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/anonymous',
      data: {'device_id': deviceId},
    );
    final data = response.data;
    if (data == null) {
      throw const AuthException('Anonymous login response is empty.');
    }
    final loginResponse = LoginResponse.fromJson(data);
    await saveToken(loginResponse.accessToken);
    return loginResponse.isNewUser;
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
    return loginWithServer(
      dio: dio,
      provider: AuthLoginProvider.google,
      token: 'dev-test-user',
    );
  }

  Future<bool> loginWithDevelopmentNewUser({required Dio dio}) {
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
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
