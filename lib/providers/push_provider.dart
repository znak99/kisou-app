import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synchronized/synchronized.dart';

import '../config/push_config.dart';
import '../models/push_notification.dart';
import '../services/push_installation_store.dart';
import '../services/push_local_metadata.dart';
import '../services/push_messaging_gateway.dart';
import '../services/push_service.dart';
import 'api_provider.dart';

final pushRuntimeEnabledProvider = Provider<bool>(
  (ref) => PushMessagingBootstrap.runtimeAvailable,
);

final pushCleanupRuntimeAvailableProvider = Provider<bool>(
  (ref) => PushMessagingBootstrap.cleanupRuntimeAvailable,
);

final pushFirebaseCleanupGatewayRequiredProvider = Provider<bool>(
  (ref) => PushMessagingBootstrap.firebaseCleanupGatewayRequired,
);

final pushInstallationStateInspectionCompleteProvider = Provider<bool>(
  (ref) => PushMessagingBootstrap.installationStateInspectionComplete,
);

final pushPlatformProvider = Provider<KisouPushPlatform?>(
  (ref) => PushConfig.currentPlatform,
);

final pushMessagingGatewayProvider = Provider<PushMessagingGateway>((ref) {
  return ref.watch(pushRuntimeEnabledProvider) ||
          ref.watch(pushFirebaseCleanupGatewayRequiredProvider)
      ? FirebasePushMessagingGateway()
      : const DisabledPushMessagingGateway();
});

final pushApiGatewayProvider = Provider<PushApiGateway>((ref) {
  return PushService(ref.watch(apiClientProvider));
});

final pushInstallationStoreProvider = Provider<PushInstallationStore>((ref) {
  return PushInstallationStore();
});

final pushPermissionHistoryProvider = Provider<PushPermissionHistory>((ref) {
  return PushPermissionHistory();
});

final pushDeliveryReceiptStoreProvider = Provider<PushDeliveryReceiptStore>((
  ref,
) {
  return PushDeliveryReceiptStore();
});

final pushAppVersionProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.isEmpty ? '0' : info.buildNumber;
    return '${info.version}+$build';
  };
});

final pushAccountManagerProvider = Provider<PushAccountManager>((ref) {
  return PushAccountManager(
    store: ref.watch(pushInstallationStoreProvider),
    messaging: ref.watch(pushMessagingGatewayProvider),
    api: ref.watch(pushApiGatewayProvider),
    platform: ref.watch(pushPlatformProvider),
    appVersionFactory: ref.watch(pushAppVersionProvider),
  );
});

class PushAccountManager {
  const PushAccountManager({
    required PushInstallationStore store,
    required PushMessagingGateway messaging,
    required PushApiGateway api,
    required KisouPushPlatform? platform,
    required Future<String> Function() appVersionFactory,
  }) : _store = store,
       _messaging = messaging,
       _api = api,
       _platform = platform,
       _appVersionFactory = appVersionFactory;

  final PushInstallationStore _store;
  final PushMessagingGateway _messaging;
  final PushApiGateway _api;
  final KisouPushPlatform? _platform;
  final Future<String> Function() _appVersionFactory;

  Future<int> readAccountGeneration() async {
    return (await _store.readSnapshot()).accountGeneration;
  }

  Future<void> register({
    required int accountGeneration,
    String? refreshedToken,
  }) async {
    final platform = _platform;
    if (platform == null) {
      throw StateError('Push registration requires Android or iOS.');
    }
    await _store.registerPreparedIfCurrent(
      accountGeneration: accountGeneration,
      prepare: () async {
        await _messaging.prepareNotificationPresentation();
        final token = refreshedToken ?? await _messaging.getToken();
        if (token.isEmpty || token.length > 4096) {
          throw const PushTokenUnavailableException();
        }
        final tokenHash = sha256.convert(utf8.encode(token)).toString();
        final appVersion = await _appVersionFactory();
        return PreparedPushRegistration(
          platform: platform,
          tokenHash: tokenHash,
          appVersion: appVersion,
          send:
              (
                installationId,
                clientRevision,
                registeredPlatform,
                registeredAppVersion,
              ) {
                return _api.registerDevice(
                  installationId: installationId,
                  clientRevision: clientRevision,
                  platform: registeredPlatform,
                  fcmToken: token,
                  appVersion: registeredAppVersion,
                );
              },
        );
      },
    );
  }

  Future<PushInstallationSnapshot> closeAccount({
    bool suppressAuthRecovery = true,
  }) async {
    final snapshot = await _store.closeAccount(
      send: (installationId, clientRevision) {
        return _api.unregisterDevice(
          installationId: installationId,
          clientRevision: clientRevision,
          suppressAuthRecovery: suppressAuthRecovery,
        );
      },
      deletePlatformToken: _messaging.disableAndDeleteToken,
    );
    if (snapshot.record?.platformCleanupRequired == true) {
      throw PushAccountCloseIncompleteException(snapshot);
    }
    return snapshot;
  }
}

class PushAccountCloseIncompleteException implements Exception {
  const PushAccountCloseIncompleteException(this.snapshot);

  final PushInstallationSnapshot snapshot;
}

PushPermissionState resolvePushPermissionState({
  required PushPlatformAuthorization authorization,
  required KisouPushPlatform? platform,
  required int promptCount,
}) {
  return switch (authorization) {
    PushPlatformAuthorization.authorized ||
    PushPlatformAuthorization.provisional => PushPermissionState.allowed,
    PushPlatformAuthorization.notDetermined =>
      PushPermissionState.notDetermined,
    PushPlatformAuthorization.denied =>
      platform == KisouPushPlatform.ios || promptCount >= 2
          ? PushPermissionState.blocked
          : PushPermissionState.denied,
  };
}

enum PushSettingsError { save, registration, permission, settings }

class PushSettingsState {
  const PushSettingsState({
    required this.available,
    required this.preferences,
    required this.permission,
    required this.registrationReady,
    this.isSaving = false,
    this.error,
  });

  const PushSettingsState.unavailable()
    : this(
        available: false,
        preferences: PushPreferences.defaults,
        permission: PushPermissionState.unavailable,
        registrationReady: false,
      );

  final bool available;
  final PushPreferences preferences;
  final PushPermissionState permission;
  final bool registrationReady;
  final bool isSaving;
  final PushSettingsError? error;

  PushSettingsState copyWith({
    PushPreferences? preferences,
    PushPermissionState? permission,
    bool? registrationReady,
    bool? isSaving,
    PushSettingsError? error,
    bool clearError = false,
  }) {
    return PushSettingsState(
      available: available,
      preferences: preferences ?? this.preferences,
      permission: permission ?? this.permission,
      registrationReady: registrationReady ?? this.registrationReady,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final pushSettingsProvider =
    AsyncNotifierProvider<PushSettingsController, PushSettingsState>(
      PushSettingsController.new,
    );

class PushSettingsController extends AsyncNotifier<PushSettingsState> {
  final _settingsLock = Lock();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  var _generation = 0;
  int? _accountGeneration;

  @override
  Future<PushSettingsState> build() async {
    final operation = ++_generation;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    ref.onDispose(() {
      _generation++;
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
    });
    if (!ref.read(pushRuntimeEnabledProvider)) {
      if (ref.read(pushCleanupRuntimeAvailableProvider)) {
        try {
          await ref
              .read(pushAccountManagerProvider)
              .closeAccount(suppressAuthRecovery: false);
        } catch (_) {
          // The durable unregister intent is retried at the next account
          // boundary/startup. Push remains unavailable in this build.
        }
      }
      return const PushSettingsState.unavailable();
    }
    final messaging = ref.read(pushMessagingGatewayProvider);
    _subscriptions
      ..add(
        messaging.foregroundMessages.listen(
          (message) => _handleForegroundMessage(message, operation),
        ),
      )
      ..add(
        messaging.notificationTaps.listen(
          (message) => _handleNotificationTap(message, operation),
        ),
      )
      ..add(
        messaging.tokenRefreshes.listen(
          (token) => _handleTokenRefresh(token, operation),
        ),
      );
    try {
      final pending = await ref
          .read(pushDeliveryReceiptStoreProvider)
          .pendingNavigations();
      if (_isCurrent(operation)) {
        for (final intent in pending) {
          final allowed = await _isRoutingRevisionCurrent(intent);
          if (!_isCurrent(operation)) {
            break;
          }
          if (allowed) {
            ref.read(pushNavigationQueueProvider.notifier).queue(intent);
          } else {
            await ref
                .read(pushDeliveryReceiptStoreProvider)
                .completeNavigation(intent.deliveryId);
          }
        }
      }
    } catch (_) {
      // Corrupt consume-once state fails closed and does not route.
    }
    try {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && _isCurrent(operation)) {
        await _handleNotificationTap(initialMessage, operation);
      }
    } catch (_) {
      // A malformed/unavailable cold-start message must not block the app.
    }
    final preferences = await ref.read(pushApiGatewayProvider).getPreferences();
    final permission = await _readPermission();
    final manager = ref.read(pushAccountManagerProvider);
    _accountGeneration = await manager.readAccountGeneration();
    var registrationReady = false;
    PushSettingsError? syncError;
    if (_isCurrent(operation)) {
      try {
        if (preferences.anyEnabled &&
            permission == PushPermissionState.allowed) {
          await manager.register(accountGeneration: _accountGeneration!);
          registrationReady = true;
        } else {
          final closed = await manager.closeAccount(
            suppressAuthRecovery: false,
          );
          _accountGeneration = closed.accountGeneration;
        }
      } on StalePushAccountOperationException {
        // An account transition owns the final unregister.
      } catch (_) {
        syncError = PushSettingsError.registration;
      }
    }
    return PushSettingsState(
      available: true,
      preferences: preferences,
      permission: permission,
      registrationReady: registrationReady,
      error: syncError,
    );
  }

  Future<void> setMorningEnabled(bool enabled) {
    return _setEnabled(
      enabled: enabled,
      update: (preferences) => preferences.copyWith(morningEnabled: enabled),
    );
  }

  Future<void> setEveningEnabled(bool enabled) {
    return _setEnabled(
      enabled: enabled,
      update: (preferences) => preferences.copyWith(eveningEnabled: enabled),
    );
  }

  Future<void> setMorningTime(NotificationTime time) {
    return _updatePreferences(
      (preferences) => preferences.copyWith(morningTime: time),
    );
  }

  Future<void> setEveningTime(NotificationTime time) {
    return _updatePreferences(
      (preferences) => preferences.copyWith(eveningTime: time),
    );
  }

  Future<void> requestPermissionAndSync() {
    return _settingsLock.synchronized(() async {
      final current = state.value;
      if (current == null ||
          !current.available ||
          !current.preferences.anyEnabled) {
        return;
      }
      state = AsyncData(current.copyWith(isSaving: true, clearError: true));
      if (current.permission == PushPermissionState.allowed) {
        try {
          await _ensureRegistered();
          state = AsyncData(
            current.copyWith(
              registrationReady: true,
              isSaving: false,
              clearError: true,
            ),
          );
        } catch (_) {
          _finishWithError(PushSettingsError.registration);
        }
        return;
      }
      await _requestPermissionAndRegister();
    });
  }

  Future<void> refreshAuthorizationAfterResume() {
    return _settingsLock.synchronized(() async {
      final current = state.value;
      if (current == null || !current.available || current.isSaving) {
        return;
      }
      final permission = await _readPermission();
      if (state.value == null) {
        return;
      }
      if (permission == PushPermissionState.allowed &&
          current.preferences.anyEnabled) {
        try {
          await _ensureRegistered();
          state = AsyncData(
            current.copyWith(
              permission: permission,
              registrationReady: true,
              clearError: true,
            ),
          );
        } catch (_) {
          state = AsyncData(
            current.copyWith(
              permission: permission,
              registrationReady: false,
              error: PushSettingsError.registration,
            ),
          );
        }
        return;
      }
      if (permission != PushPermissionState.allowed) {
        try {
          final closed = await ref
              .read(pushAccountManagerProvider)
              .closeAccount(suppressAuthRecovery: false);
          _accountGeneration = closed.accountGeneration;
        } catch (_) {
          // Keep the visible permission status; account cleanup retries later.
        }
      }
      state = AsyncData(
        current.copyWith(permission: permission, registrationReady: false),
      );
    });
  }

  Future<bool> openAppSettings() {
    return ref.read(pushMessagingGatewayProvider).openAppSettings();
  }

  Future<void> openForegroundNotification(String deliveryId) async {
    final operation = _generation;
    final notice = ref.read(pushForegroundNotificationProvider);
    if (notice == null || notice.deliveryId != deliveryId) {
      return;
    }
    ref.read(pushForegroundNotificationProvider.notifier).clear(deliveryId);
    await _queueNavigation(notice, operation: operation);
  }

  void dismissForegroundNotification(String deliveryId) {
    ref.read(pushForegroundNotificationProvider.notifier).clear(deliveryId);
  }

  Future<void> retry() async {
    await PushMessagingBootstrap.retryInitialization();
    ref
      ..invalidate(pushRuntimeEnabledProvider)
      ..invalidate(pushCleanupRuntimeAvailableProvider)
      ..invalidate(pushFirebaseCleanupGatewayRequiredProvider)
      ..invalidate(pushInstallationStateInspectionCompleteProvider)
      ..invalidate(pushMessagingGatewayProvider)
      ..invalidate(pushAccountManagerProvider);
    ref.invalidateSelf();
  }

  Future<void> _setEnabled({
    required bool enabled,
    required PushPreferences Function(PushPreferences) update,
  }) {
    return _settingsLock.synchronized(() async {
      final current = state.value;
      if (current == null || !current.available || current.isSaving) {
        return;
      }
      final nextPreferences = update(current.preferences);
      if (nextPreferences == current.preferences) {
        if (enabled && current.permission != PushPermissionState.allowed) {
          state = AsyncData(current.copyWith(isSaving: true, clearError: true));
          await _requestPermissionAndRegister();
        }
        return;
      }
      state = AsyncData(current.copyWith(isSaving: true, clearError: true));
      if (enabled && current.permission != PushPermissionState.allowed) {
        final allowed = await _requestPermissionOnly();
        if (!allowed) {
          return;
        }
      }
      if (enabled) {
        try {
          await _ensureRegistered();
        } catch (_) {
          if (!current.preferences.anyEnabled) {
            await _rollbackInactiveRegistration();
          }
          _finishWithError(PushSettingsError.registration);
          return;
        }
      }
      await _savePreferences(
        nextPreferences,
        rollbackRegistrationOnFailure:
            enabled && !current.preferences.anyEnabled,
        registrationAlreadyReady: enabled,
      );
    });
  }

  Future<void> _updatePreferences(
    PushPreferences Function(PushPreferences) update,
  ) {
    return _settingsLock.synchronized(() async {
      final current = state.value;
      if (current == null || !current.available || current.isSaving) {
        return;
      }
      final next = update(current.preferences);
      if (next == current.preferences) {
        return;
      }
      state = AsyncData(current.copyWith(isSaving: true, clearError: true));
      await _savePreferences(next);
    });
  }

  Future<void> _savePreferences(
    PushPreferences next, {
    bool rollbackRegistrationOnFailure = false,
    bool registrationAlreadyReady = false,
  }) async {
    PushPreferences saved;
    try {
      saved = await ref.read(pushApiGatewayProvider).updatePreferences(next);
    } catch (_) {
      if (rollbackRegistrationOnFailure) {
        await _rollbackInactiveRegistration();
      }
      _finishWithError(PushSettingsError.save);
      return;
    }

    PushPermissionState permission;
    try {
      permission = await _readPermission();
    } catch (_) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          PushSettingsState(
            available: true,
            preferences: saved,
            permission: current.permission,
            registrationReady: false,
            error: PushSettingsError.permission,
          ),
        );
      }
      return;
    }

    var registrationReady = false;
    PushSettingsError? error;
    if (!saved.anyEnabled) {
      try {
        final closed = await ref
            .read(pushAccountManagerProvider)
            .closeAccount(suppressAuthRecovery: false);
        _accountGeneration = closed.accountGeneration;
      } catch (_) {
        error = PushSettingsError.registration;
      }
    } else if (permission == PushPermissionState.allowed) {
      if (registrationAlreadyReady) {
        registrationReady = true;
      } else {
        try {
          await _ensureRegistered();
          registrationReady = true;
        } catch (_) {
          error = PushSettingsError.registration;
        }
      }
    }
    state = AsyncData(
      PushSettingsState(
        available: true,
        preferences: saved,
        permission: permission,
        registrationReady: registrationReady,
        error: error,
      ),
    );
  }

  Future<void> _rollbackInactiveRegistration() async {
    try {
      final closed = await ref
          .read(pushAccountManagerProvider)
          .closeAccount(suppressAuthRecovery: false);
      _accountGeneration = closed.accountGeneration;
    } catch (_) {
      // Keep the original visible operation error. The durable transition
      // marker, when written, remains available for the next exact retry.
    }
  }

  Future<bool> _requestPermissionOnly() async {
    final history = ref.read(pushPermissionHistoryProvider);
    final promptCount = await history.recordPrompt();
    try {
      final authorization = await ref
          .read(pushMessagingGatewayProvider)
          .requestPermission();
      final permission = resolvePushPermissionState(
        authorization: authorization,
        platform: ref.read(pushPlatformProvider),
        promptCount: promptCount,
      );
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            permission: permission,
            isSaving: permission == PushPermissionState.allowed,
            registrationReady: false,
          ),
        );
      }
      return permission == PushPermissionState.allowed;
    } catch (_) {
      _finishWithError(PushSettingsError.permission);
      return false;
    }
  }

  Future<void> _requestPermissionAndRegister() async {
    final allowed = await _requestPermissionOnly();
    if (!allowed) {
      final current = state.value;
      if (current != null && current.isSaving) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      return;
    }
    try {
      await _ensureRegistered();
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            permission: PushPermissionState.allowed,
            registrationReady: true,
            isSaving: false,
            clearError: true,
          ),
        );
      }
    } catch (_) {
      _finishWithError(PushSettingsError.registration);
    }
  }

  Future<void> _ensureRegistered({String? refreshedToken}) async {
    _accountGeneration ??= await ref
        .read(pushAccountManagerProvider)
        .readAccountGeneration();
    await ref
        .read(pushAccountManagerProvider)
        .register(
          accountGeneration: _accountGeneration!,
          refreshedToken: refreshedToken,
        );
  }

  Future<PushPermissionState> _readPermission() async {
    final authorization = await ref
        .read(pushMessagingGatewayProvider)
        .getAuthorizationStatus();
    final count = await ref.read(pushPermissionHistoryProvider).readCount();
    return resolvePushPermissionState(
      authorization: authorization,
      platform: ref.read(pushPlatformProvider),
      promptCount: count,
    );
  }

  Future<void> _handleTokenRefresh(String token, int operation) async {
    final current = state.value;
    if (!_isCurrent(operation) ||
        current == null ||
        !current.preferences.anyEnabled ||
        current.permission != PushPermissionState.allowed) {
      return;
    }
    try {
      await _ensureRegistered(refreshedToken: token);
      if (_isCurrent(operation) && state.value != null) {
        state = AsyncData(
          state.requireValue.copyWith(
            registrationReady: true,
            clearError: true,
          ),
        );
      }
    } on StalePushAccountOperationException {
      // The account transition's unregister is authoritative.
    } catch (_) {
      if (_isCurrent(operation) && state.value != null) {
        state = AsyncData(
          state.requireValue.copyWith(
            registrationReady: false,
            error: PushSettingsError.registration,
          ),
        );
      }
    }
  }

  Future<void> _handleForegroundMessage(
    PushRemoteMessage message,
    int operation,
  ) async {
    if (!_isCurrent(operation)) {
      return;
    }
    final intent = await _parseAuthorizedIntent(message);
    if (intent == null) {
      return;
    }
    try {
      final isNew = await ref
          .read(pushDeliveryReceiptStoreProvider)
          .markForegroundIfNew(intent);
      if (!isNew || !_isCurrent(operation)) {
        return;
      }
    } catch (_) {
      // Receipt corruption/write failure fails closed: do not show a push that
      // could be duplicated after restart.
      return;
    }
    ref.read(pushForegroundNotificationProvider.notifier).show(intent);
  }

  Future<void> _handleNotificationTap(
    PushRemoteMessage message,
    int operation,
  ) async {
    if (!_isCurrent(operation)) {
      return;
    }
    final intent = await _parseAuthorizedIntent(message);
    if (intent == null) {
      return;
    }
    await _queueNavigation(intent, operation: operation);
  }

  Future<void> _queueNavigation(
    PushNotificationIntent intent, {
    required int operation,
  }) async {
    try {
      final isNew = await ref
          .read(pushDeliveryReceiptStoreProvider)
          .reserveNavigation(intent);
      if (!isNew || !_isCurrent(operation)) {
        return;
      }
    } catch (_) {
      // Persistent consume-once storage is mandatory for routing.
      return;
    }
    ref.read(pushNavigationQueueProvider.notifier).queue(intent);
  }

  Future<PushNotificationIntent?> _parseAuthorizedIntent(
    PushRemoteMessage message,
  ) async {
    try {
      final intent = PushNotificationIntent.fromData(message.data);
      return await _isRoutingRevisionCurrent(intent) ? intent : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isRoutingRevisionCurrent(PushNotificationIntent intent) async {
    final record = await ref.read(pushInstallationStoreProvider).read();
    return record?.allowsRoutingRevision(intent.clientRevision) == true;
  }

  void _finishWithError(PushSettingsError error) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          registrationReady: false,
          error: error,
        ),
      );
    }
  }

  bool _isCurrent(int operation) => operation == _generation;
}

final pushNavigationQueueProvider =
    NotifierProvider<
      PushNavigationQueueController,
      List<PushNotificationIntent>
    >(PushNavigationQueueController.new);

class PushNavigationQueueController
    extends Notifier<List<PushNotificationIntent>> {
  @override
  List<PushNotificationIntent> build() => const [];

  void queue(PushNotificationIntent intent) {
    if (state.any((item) => item.deliveryId == intent.deliveryId)) {
      return;
    }
    state = List.unmodifiable([...state.take(3), intent]);
  }

  PushNotificationIntent? consume() {
    if (state.isEmpty) {
      return null;
    }
    final first = state.first;
    state = List.unmodifiable(state.skip(1));
    return first;
  }

  void clear() {
    state = const [];
  }
}

final pushForegroundNotificationProvider =
    NotifierProvider<
      PushForegroundNotificationController,
      PushNotificationIntent?
    >(PushForegroundNotificationController.new);

class PushForegroundNotificationController
    extends Notifier<PushNotificationIntent?> {
  @override
  PushNotificationIntent? build() => null;

  void show(PushNotificationIntent intent) {
    state = intent;
  }

  void clear(String deliveryId) {
    if (state?.deliveryId == deliveryId) {
      state = null;
    }
  }
}
