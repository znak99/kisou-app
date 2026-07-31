import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/push_config.dart';
import '../models/push_notification.dart';
import 'push_installation_store.dart';

abstract interface class PushMessagingGateway {
  Stream<PushRemoteMessage> get foregroundMessages;

  Stream<PushRemoteMessage> get notificationTaps;

  Stream<String> get tokenRefreshes;

  Future<PushRemoteMessage?> getInitialMessage();

  Future<PushPlatformAuthorization> getAuthorizationStatus();

  Future<PushPlatformAuthorization> requestPermission();

  Future<void> prepareNotificationPresentation();

  Future<String> getToken();

  Future<void> disableAndDeleteToken();

  Future<void> clearDisplayedNotifications();

  Future<bool> openAppSettings();
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  FirebasePushMessagingGateway({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  static const channelId = 'push_daily_v1';
  static const _channel = AndroidNotificationChannel(
    channelId,
    '毎日のおすすめ',
    description: '朝の服装おすすめと夜の体感記録をお知らせします',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
  );

  final FirebaseMessaging _messaging;
  static const _nativeChannel = MethodChannel('jp.kisou/push');

  @override
  Stream<PushRemoteMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_toPushMessage);

  @override
  Stream<PushRemoteMessage> get notificationTaps =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPushMessage);

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<PushRemoteMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPushMessage(message);
  }

  @override
  Future<PushPlatformAuthorization> getAuthorizationStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _authorization(settings.authorizationStatus);
  }

  @override
  Future<PushPlatformAuthorization> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return _authorization(settings.authorizationStatus);
  }

  @override
  Future<void> prepareNotificationPresentation() async {
    // This is called only after a prior opt-in is confirmed or directly from
    // the user's enable action. It allows FCM to keep that opted-in token fresh.
    await _messaging.setAutoInitEnabled(true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_channel);
    }
  }

  @override
  Future<String> getToken() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // Firebase requires the APNs token before FCM token calls on Apple
      // platforms. It can arrive shortly after authorization or app startup.
      String? apnsToken;
      for (var attempt = 0; attempt < 8 && apnsToken == null; attempt++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (apnsToken == null) {
        throw const PushTokenUnavailableException();
      }
    }
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty || token.length > 4096) {
      throw const PushTokenUnavailableException();
    }
    return token;
  }

  @override
  Future<void> disableAndDeleteToken() async {
    await performPushPlatformCleanup(
      disableAutoInit: () => _messaging.setAutoInitEnabled(false),
      deleteMessagingToken: _messaging.deleteToken,
      deleteFirebaseInstallation: FirebaseInstallations.instance.delete,
    );
  }

  @override
  Future<void> clearDisplayedNotifications() {
    return _nativeChannel.invokeMethod<void>('clearDisplayedPushNotifications');
  }

  @override
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}

class DisabledPushMessagingGateway implements PushMessagingGateway {
  const DisabledPushMessagingGateway();

  @override
  Stream<PushRemoteMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<PushRemoteMessage> get notificationTaps => const Stream.empty();

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Future<void> clearDisplayedNotifications() {
    return const MethodChannel(
      'jp.kisou/push',
    ).invokeMethod<void>('clearDisplayedPushNotifications');
  }

  @override
  Future<void> disableAndDeleteToken() {
    throw const PushPlatformCleanupUnavailableException();
  }

  @override
  Future<PushPlatformAuthorization> getAuthorizationStatus() async {
    return PushPlatformAuthorization.denied;
  }

  @override
  Future<PushRemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String> getToken() {
    throw const PushTokenUnavailableException();
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<void> prepareNotificationPresentation() async {}

  @override
  Future<PushPlatformAuthorization> requestPermission() async {
    return PushPlatformAuthorization.denied;
  }
}

class MemoryPushMessagingGateway implements PushMessagingGateway {
  MemoryPushMessagingGateway({
    this.authorization = PushPlatformAuthorization.authorized,
    this.permissionRequestResult,
    this.token = 'memory-fcm-token',
  });

  PushPlatformAuthorization authorization;
  PushPlatformAuthorization? permissionRequestResult;
  String token;
  var permissionRequestCount = 0;
  var tokenReadCount = 0;
  var deleteTokenCount = 0;
  var deleteInstallationCount = 0;
  var presentationPreparationCount = 0;
  var autoInitEnabled = false;
  var settingsOpenCount = 0;
  var clearDisplayedCount = 0;
  PushRemoteMessage? initialMessage;
  final foregroundController = StreamController<PushRemoteMessage>.broadcast();
  final tapController = StreamController<PushRemoteMessage>.broadcast();
  final tokenController = StreamController<String>.broadcast();

  @override
  Stream<PushRemoteMessage> get foregroundMessages =>
      foregroundController.stream;

  @override
  Stream<PushRemoteMessage> get notificationTaps => tapController.stream;

  @override
  Stream<String> get tokenRefreshes => tokenController.stream;

  @override
  Future<void> clearDisplayedNotifications() async {
    clearDisplayedCount++;
  }

  @override
  Future<void> disableAndDeleteToken() async {
    autoInitEnabled = false;
    deleteTokenCount++;
    deleteInstallationCount++;
  }

  @override
  Future<PushPlatformAuthorization> getAuthorizationStatus() async {
    return authorization;
  }

  @override
  Future<PushRemoteMessage?> getInitialMessage() async {
    final result = initialMessage;
    initialMessage = null;
    return result;
  }

  @override
  Future<String> getToken() async {
    tokenReadCount++;
    return token;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpenCount++;
    return true;
  }

  @override
  Future<void> prepareNotificationPresentation() async {
    autoInitEnabled = true;
    presentationPreparationCount++;
  }

  @override
  Future<PushPlatformAuthorization> requestPermission() async {
    permissionRequestCount++;
    authorization = permissionRequestResult ?? authorization;
    return authorization;
  }

  Future<void> close() async {
    await foregroundController.close();
    await tapController.close();
    await tokenController.close();
  }
}

class PushMessagingBootstrap {
  const PushMessagingBootstrap._();

  static Future<void>? _initialization;
  static Future<void>? _retryInitialization;
  static var _runtimeAvailable = false;
  static var _cleanupRuntimeAvailable = false;
  static var _firebaseCleanupGatewayRequired = false;
  // The app entry point always calls initializeForRuntime before providers
  // exist; that call resets this to false and performs the real inspection.
  // The pre-bootstrap value keeps isolated provider tests equivalent to an
  // empty, unsupported host rather than an unreadable mobile Keychain.
  static var _installationStateInspectionComplete = true;

  static bool get runtimeAvailable => _runtimeAvailable;
  static bool get cleanupRuntimeAvailable => _cleanupRuntimeAvailable;
  static bool get firebaseCleanupGatewayRequired =>
      _firebaseCleanupGatewayRequired;
  static bool get installationStateInspectionComplete =>
      _installationStateInspectionComplete;

  static Future<void> initializeForRuntime() {
    final inFlight = _initialization;
    if (inFlight != null) {
      return inFlight;
    }
    final initialization = _initializeForRuntime().onError((_, _) {
      // Build-time configuration is validated before this method. Every
      // remaining error is device/runtime-specific and must stay optional.
      _runtimeAvailable = false;
    });
    _initialization = initialization;
    return initialization;
  }

  static Future<void> retryInitialization() {
    final inFlight = _retryInitialization;
    if (inFlight != null) {
      return inFlight;
    }
    late final Future<void> retry;
    retry =
        () async {
          await _initialization;
          if (_runtimeAvailable) {
            return;
          }
          _initialization = null;
          await initializeForRuntime();
        }().whenComplete(() {
          if (identical(_retryInitialization, retry)) {
            _retryInitialization = null;
          }
        });
    _retryInitialization = retry;
    return retry;
  }

  static Future<void> _initializeForRuntime() async {
    _runtimeAvailable = false;
    _cleanupRuntimeAvailable = false;
    _firebaseCleanupGatewayRequired = false;
    _installationStateInspectionComplete = false;
    if (PushConfig.enabled) {
      var firebaseInitialized = false;
      try {
        await _initializeFirebase(
          options: PushConfig.firebaseOptions,
          registerBackgroundHandler: true,
        );
        firebaseInitialized = true;
        // Native manifests default this off. Reassert false for installations
        // where an older build may have persisted auto-init=true.
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        _runtimeAvailable = true;
      } catch (_) {
        // Push is optional. A device-specific Firebase failure must not block
        // weather, auth, or other non-push features from starting.
        await _recoverCleanupState(firebaseInitialized: firebaseInitialized);
      }
      return;
    }

    // A newly installed disabled build reads only local secure state and never
    // initializes Firebase. Server tombstones can also be retried without it.
    final store = PushInstallationStore();
    PushInstallationRecord? record;
    try {
      record = await store.read();
      _installationStateInspectionComplete = true;
    } on PushInstallationCorruptException {
      // Key presence is sufficient evidence that an older process may have
      // activated Firebase. Initialize only the cleanup gateway; the
      // authenticated account boundary replaces the corrupt value after
      // token/FID cleanup succeeds.
      _cleanupRuntimeAvailable = true;
      try {
        await _initializeFirebase(
          options: PushConfig.cleanupFirebaseOptions,
          registerBackgroundHandler: false,
        );
        _firebaseCleanupGatewayRequired = true;
        // An older persisted native preference can override the manifest.
        // Reassert the safest stage immediately; account close repeats the
        // complete three-stage cleanup before replacing the corrupt record.
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
      } catch (_) {
        // Missing credentials or a device Firebase failure leaves the corrupt
        // secure value untouched so a later retry remains fail-closed.
      }
      return;
    } catch (_) {
      // Corrupt/unavailable Keychain state is isolated to push. Do not guess
      // whether Firebase is safe to initialize and do not erase the marker.
      return;
    }
    if (record?.requiresCleanup != true) {
      return;
    }
    _cleanupRuntimeAvailable = true;
    if (record!.platformCleanupRequired) {
      // The durable marker was written before Firebase activation. Missing or
      // malformed retained identifiers fail closed instead of silently leaving
      // a persisted native auto-init value behind.
      try {
        await _initializeFirebase(
          options: PushConfig.cleanupFirebaseOptions,
          registerBackgroundHandler: false,
        );
      } catch (_) {
        // Server unregister can still proceed through the disabled gateway.
        // The platform marker remains for the next app start.
        return;
      }
      _firebaseCleanupGatewayRequired = true;
      try {
        await performPushPlatformCleanup(
          disableAutoInit: () =>
              FirebaseMessaging.instance.setAutoInitEnabled(false),
          deleteMessagingToken: FirebaseMessaging.instance.deleteToken,
          deleteFirebaseInstallation: FirebaseInstallations.instance.delete,
        );
        record = await store.completePlatformCleanup();
        _firebaseCleanupGatewayRequired = false;
      } catch (_) {
        // Keep both the marker and Firebase cleanup gateway available. The
        // authenticated transition/settings startup retries the same cleanup.
      }
    }
    _cleanupRuntimeAvailable = record?.requiresCleanup == true;
  }

  static Future<void> _recoverCleanupState({
    required bool firebaseInitialized,
  }) async {
    try {
      final record = await PushInstallationStore().read();
      _installationStateInspectionComplete = true;
      _cleanupRuntimeAvailable = record?.requiresCleanup == true;
      _firebaseCleanupGatewayRequired =
          firebaseInitialized && record?.platformCleanupRequired == true;
    } on PushInstallationCorruptException {
      _cleanupRuntimeAvailable = true;
      _firebaseCleanupGatewayRequired = firebaseInitialized;
    } catch (_) {
      // A secure-state failure remains isolated and is retried next start.
    }
  }

  static Future<void> _initializeFirebase({
    required FirebaseOptions options,
    required bool registerBackgroundHandler,
  }) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    if (registerBackgroundHandler) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!PushConfig.enabled) {
    return;
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: PushConfig.firebaseOptions);
  }
  // The OS displays the generic notification. Navigation is intentionally
  // deferred to getInitialMessage/onMessageOpenedApp in the authenticated UI.
}

class PushTokenUnavailableException implements Exception {
  const PushTokenUnavailableException();
}

class PushPlatformCleanupUnavailableException implements Exception {
  const PushPlatformCleanupUnavailableException();
}

/// Deletes all Firebase state used solely for push, in privacy-preserving order.
///
/// Callers clear the durable cleanup marker only after this Future completes.
Future<void> performPushPlatformCleanup({
  required Future<void> Function() disableAutoInit,
  required Future<void> Function() deleteMessagingToken,
  required Future<void> Function() deleteFirebaseInstallation,
}) async {
  await disableAutoInit();
  await deleteMessagingToken();
  await deleteFirebaseInstallation();
}

PushRemoteMessage _toPushMessage(RemoteMessage message) {
  return PushRemoteMessage(
    data: Map.unmodifiable({
      for (final entry in message.data.entries)
        if (entry.value is String) entry.key: entry.value as String,
    }),
  );
}

PushPlatformAuthorization _authorization(AuthorizationStatus status) {
  return switch (status) {
    AuthorizationStatus.notDetermined =>
      PushPlatformAuthorization.notDetermined,
    AuthorizationStatus.authorized => PushPlatformAuthorization.authorized,
    AuthorizationStatus.provisional => PushPlatformAuthorization.provisional,
    AuthorizationStatus.denied => PushPlatformAuthorization.denied,
  };
}
