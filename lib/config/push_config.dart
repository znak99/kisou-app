import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum KisouPushPlatform { android, ios }

bool parsePushEnabled(String value) {
  return switch (value) {
    'true' => true,
    'false' => false,
    _ => throw StateError(
      'PUSH_NOTIFICATIONS_ENABLED must be exactly true or false.',
    ),
  };
}

FirebaseOptions resolvePushFirebaseOptions({
  required bool enabled,
  bool allowDisabledCleanup = false,
  required KisouPushPlatform? platform,
  required String apiKey,
  required String appId,
  required String messagingSenderId,
  required String projectId,
  required String? iosBundleId,
  required String environment,
}) {
  if (!enabled && !allowDisabledCleanup) {
    throw StateError(
      'Firebase options are unavailable while push is disabled.',
    );
  }
  if (environment != 'development' && environment != 'production') {
    throw StateError('Unsupported push environment.');
  }
  if (platform == null) {
    throw StateError('Push notifications support only Android and iOS.');
  }
  if (!_firebaseApiKeyPattern.hasMatch(apiKey) ||
      !_firebaseSenderIdPattern.hasMatch(messagingSenderId) ||
      !_firebaseProjectIdPattern.hasMatch(projectId)) {
    throw StateError('Firebase push configuration is missing or malformed.');
  }
  final expectedPlatform = platform == KisouPushPlatform.android
      ? 'android'
      : 'ios';
  final appIdPattern = RegExp(
    '^1:${RegExp.escape(messagingSenderId)}:$expectedPlatform:'
    r'[0-9a-f]{16,64}$',
  );
  if (!appIdPattern.hasMatch(appId)) {
    throw StateError(
      'Firebase App ID does not match the sender ID and native platform.',
    );
  }
  if (platform == KisouPushPlatform.ios &&
      (iosBundleId == null ||
          !_appleBundleIdPattern.hasMatch(iosBundleId) ||
          iosBundleId.contains('.dev') != (environment == 'development'))) {
    throw StateError('Firebase iOS bundle ID does not match this environment.');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    iosBundleId: platform == KisouPushPlatform.ios ? iosBundleId : null,
  );
}

class PushConfig {
  const PushConfig._();

  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );
  static const _enabledValue = String.fromEnvironment(
    'PUSH_NOTIFICATIONS_ENABLED',
    defaultValue: 'false',
  );

  static final bool enabled = parsePushEnabled(_enabledValue);

  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _androidSenderId = String.fromEnvironment(
    'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
  );
  static const _androidProjectId = String.fromEnvironment(
    'FIREBASE_ANDROID_PROJECT_ID',
  );
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosSenderId = String.fromEnvironment(
    'FIREBASE_IOS_MESSAGING_SENDER_ID',
  );
  static const _iosProjectId = String.fromEnvironment(
    'FIREBASE_IOS_PROJECT_ID',
  );
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static KisouPushPlatform? get currentPlatform {
    if (kIsWeb) {
      return null;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => KisouPushPlatform.android,
      TargetPlatform.iOS => KisouPushPlatform.ios,
      _ => null,
    };
  }

  static FirebaseOptions get firebaseOptions =>
      _firebaseOptions(allowDisabledCleanup: false);

  static FirebaseOptions get cleanupFirebaseOptions =>
      _firebaseOptions(allowDisabledCleanup: true);

  static FirebaseOptions _firebaseOptions({
    required bool allowDisabledCleanup,
  }) {
    final platform = currentPlatform;
    return resolvePushFirebaseOptions(
      enabled: enabled,
      allowDisabledCleanup: allowDisabledCleanup,
      platform: platform,
      apiKey: platform == KisouPushPlatform.android
          ? _androidApiKey
          : _iosApiKey,
      appId: platform == KisouPushPlatform.android ? _androidAppId : _iosAppId,
      messagingSenderId: platform == KisouPushPlatform.android
          ? _androidSenderId
          : _iosSenderId,
      projectId: platform == KisouPushPlatform.android
          ? _androidProjectId
          : _iosProjectId,
      iosBundleId: platform == KisouPushPlatform.ios ? _iosBundleId : null,
      environment: environment,
    );
  }

  static void validateRuntime() {
    // Parse even while disabled so an invalid boolean never silently disables
    // a production feature. Firebase identifiers are intentionally ignored
    // while disabled and no Firebase API is touched.
    enabled;
    if (enabled) {
      firebaseOptions;
    }
  }
}

final _firebaseApiKeyPattern = RegExp(r'^AIza[0-9A-Za-z_-]{35}$');
final _firebaseSenderIdPattern = RegExp(r'^[1-9][0-9]{5,19}$');
final _firebaseProjectIdPattern = RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$');
final _appleBundleIdPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$',
);
