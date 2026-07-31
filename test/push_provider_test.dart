import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisou_app/config/push_config.dart';
import 'package:kisou_app/models/push_notification.dart';
import 'package:kisou_app/providers/push_provider.dart';
import 'package:kisou_app/services/push_installation_store.dart';
import 'package:kisou_app/services/push_local_metadata.dart';
import 'package:kisou_app/services/push_messaging_gateway.dart';
import 'package:kisou_app/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _installationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'fresh opted-out startup makes no permission, token, or cleanup call',
    () async {
      final gateway = MemoryPushMessagingGateway(
        authorization: PushPlatformAuthorization.notDetermined,
      );
      final api = _FakePushApi();
      final store = _store();
      final container = _container(gateway: gateway, api: api, store: store);
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });

      final state = await container.read(pushSettingsProvider.future);

      expect(state.preferences, PushPreferences.defaults);
      expect(gateway.permissionRequestCount, 0);
      expect(gateway.tokenReadCount, 0);
      expect(gateway.deleteTokenCount, 0);
      expect(gateway.deleteInstallationCount, 0);
      expect(api.registerCalls, 0);
      expect(api.unregisterCalls, 0);
    },
  );

  test(
    'first opt-in requests once, registers, saves, and all-off fully cleans',
    () async {
      final gateway = MemoryPushMessagingGateway(
        authorization: PushPlatformAuthorization.notDetermined,
        permissionRequestResult: PushPlatformAuthorization.authorized,
      );
      final api = _FakePushApi();
      final store = _store();
      final container = _container(gateway: gateway, api: api, store: store);
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });
      await container.read(pushSettingsProvider.future);

      await container
          .read(pushSettingsProvider.notifier)
          .setMorningEnabled(true);
      final enabled = container.read(pushSettingsProvider).requireValue;

      expect(gateway.permissionRequestCount, 1);
      expect(gateway.tokenReadCount, 1);
      expect(enabled.preferences.morningEnabled, isTrue);
      expect(enabled.permission, PushPermissionState.allowed);
      expect(enabled.registrationReady, isTrue);
      expect(api.registerCalls, 1);
      expect(api.preferences.morningEnabled, isTrue);

      await container
          .read(pushSettingsProvider.notifier)
          .setMorningEnabled(false);
      final disabled = container.read(pushSettingsProvider).requireValue;

      expect(disabled.preferences.anyEnabled, isFalse);
      expect(api.unregisterCalls, 1);
      expect(gateway.deleteTokenCount, 1);
      expect(gateway.deleteInstallationCount, 1);
      expect((await store.read())?.requiresCleanup, isFalse);
    },
  );

  test(
    'permission denial leaves server preferences and Firebase untouched',
    () async {
      final gateway = MemoryPushMessagingGateway(
        authorization: PushPlatformAuthorization.notDetermined,
        permissionRequestResult: PushPlatformAuthorization.denied,
      );
      final api = _FakePushApi();
      final store = _store();
      final container = _container(gateway: gateway, api: api, store: store);
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });
      await container.read(pushSettingsProvider.future);

      await container
          .read(pushSettingsProvider.notifier)
          .setEveningEnabled(true);
      final state = container.read(pushSettingsProvider).requireValue;

      expect(state.preferences.anyEnabled, isFalse);
      expect(state.permission, PushPermissionState.denied);
      expect(gateway.permissionRequestCount, 1);
      expect(gateway.tokenReadCount, 0);
      expect(api.updateCalls, 0);
      expect(api.registerCalls, 0);
      expect(await store.read(), isNull);
    },
  );

  test(
    'preference save failure rolls back token, FID, and server registration',
    () async {
      final gateway = MemoryPushMessagingGateway();
      final api = _FakePushApi()..failUpdates = true;
      final store = _store();
      final container = _container(gateway: gateway, api: api, store: store);
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });
      await container.read(pushSettingsProvider.future);

      await container
          .read(pushSettingsProvider.notifier)
          .setMorningEnabled(true);
      final state = container.read(pushSettingsProvider).requireValue;

      expect(state.preferences.anyEnabled, isFalse);
      expect(state.error, PushSettingsError.save);
      expect(api.registerCalls, 1);
      expect(api.unregisterCalls, 1);
      expect(gateway.deleteTokenCount, 1);
      expect(gateway.deleteInstallationCount, 1);
      expect((await store.read())?.requiresCleanup, isFalse);
    },
  );

  test(
    'foreground, tap, and initial routing require the current revision',
    () async {
      final gateway = MemoryPushMessagingGateway(token: 'token-b');
      final api = _FakePushApi(
        preferences: PushPreferences.defaults.copyWith(morningEnabled: true),
      );
      final store = _store();
      await _registerDirect(store, token: 'token-a');
      await _registerDirect(store, token: 'token-b');
      gateway.initialMessage = _message(revision: 1, suffix: 1);
      final container = _container(gateway: gateway, api: api, store: store);
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });

      await container.read(pushSettingsProvider.future);
      expect(container.read(pushNavigationQueueProvider), isEmpty);

      gateway.foregroundController.add(_message(revision: 2, suffix: 2));
      await _flushEvents();
      expect(
        container.read(pushForegroundNotificationProvider)?.clientRevision,
        2,
      );

      gateway.tapController.add(_message(revision: 1, suffix: 3));
      await _flushEvents();
      expect(container.read(pushNavigationQueueProvider), isEmpty);

      gateway.tapController.add(_message(revision: 2, suffix: 4));
      await _flushEvents();
      expect(container.read(pushNavigationQueueProvider), hasLength(1));
      expect(
        container.read(pushNavigationQueueProvider).single.clientRevision,
        2,
      );
    },
  );

  test('response-loss pending register revision is routable', () async {
    final gateway = MemoryPushMessagingGateway();
    final api = _FakePushApi(
      preferences: PushPreferences.defaults.copyWith(eveningEnabled: true),
    );
    final store = _store();
    final generation = (await store.readSnapshot()).accountGeneration;
    await expectLater(
      store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _hash(gateway.token),
        appVersion: '1.0.0+1',
        send: (_, _, _, _) async => throw StateError('response lost'),
      ),
      throwsStateError,
    );
    gateway.initialMessage = _message(revision: 1, suffix: 5);
    final container = _container(gateway: gateway, api: api, store: store);
    addTearDown(() async {
      container.dispose();
      await gateway.close();
    });

    await container.read(pushSettingsProvider.future);

    expect(container.read(pushNavigationQueueProvider), hasLength(1));
    expect((await store.read())?.activeRevision, 1);
  });

  test(
    'restored pending navigation with a stale revision is discarded',
    () async {
      final gateway = MemoryPushMessagingGateway(token: 'token-b');
      final api = _FakePushApi(
        preferences: PushPreferences.defaults.copyWith(morningEnabled: true),
      );
      final store = _store();
      await _registerDirect(store, token: 'token-a');
      await _registerDirect(store, token: 'token-b');
      final stale = PushNotificationIntent(
        type: PushNotificationType.morningRecommendation,
        deliveryId: '00000000-0000-4000-8000-000000000006',
        clientRevision: 1,
      );
      await PushDeliveryReceiptStore().reserveNavigation(stale);
      final container = _container(gateway: gateway, api: api, store: store);
      addTearDown(() async {
        container.dispose();
        await gateway.close();
      });

      await container.read(pushSettingsProvider.future);

      expect(container.read(pushNavigationQueueProvider), isEmpty);
      expect(await PushDeliveryReceiptStore().pendingNavigations(), isEmpty);
    },
  );
}

ProviderContainer _container({
  required MemoryPushMessagingGateway gateway,
  required _FakePushApi api,
  required PushInstallationStore store,
}) {
  return ProviderContainer(
    overrides: [
      pushRuntimeEnabledProvider.overrideWithValue(true),
      pushCleanupRuntimeAvailableProvider.overrideWithValue(false),
      pushFirebaseCleanupGatewayRequiredProvider.overrideWithValue(false),
      pushMessagingGatewayProvider.overrideWithValue(gateway),
      pushApiGatewayProvider.overrideWithValue(api),
      pushInstallationStoreProvider.overrideWithValue(store),
      pushPlatformProvider.overrideWithValue(KisouPushPlatform.android),
      pushAppVersionProvider.overrideWithValue(() async => '1.0.0+1'),
    ],
  );
}

PushInstallationStore _store() {
  return PushInstallationStore(
    storage: _MemorySecureStorage(),
    installationIdFactory: () => _installationId,
  );
}

Future<void> _registerDirect(
  PushInstallationStore store, {
  required String token,
}) async {
  final generation = (await store.readSnapshot()).accountGeneration;
  await store.registerIfCurrent(
    accountGeneration: generation,
    platform: KisouPushPlatform.android,
    tokenHash: _hash(token),
    appVersion: '1.0.0+1',
    send: (_, _, _, _) async {},
  );
}

String _hash(String token) => sha256.convert(utf8.encode(token)).toString();

PushRemoteMessage _message({required int revision, required int suffix}) {
  return PushRemoteMessage(
    data: {
      'schema_version': '1',
      'type': suffix.isEven ? 'morning_recommendation' : 'evening_feedback',
      'delivery_id':
          '00000000-0000-4000-8000-'
          '${suffix.toRadixString(16).padLeft(12, '0')}',
      'client_revision': '$revision',
    },
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

class _MemorySecureStorage extends FlutterSecureStorage {
  String? value;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return value;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    this.value = value;
  }
}

class _FakePushApi implements PushApiGateway {
  _FakePushApi({this.preferences = PushPreferences.defaults});

  PushPreferences preferences;
  bool failUpdates = false;
  var getCalls = 0;
  var updateCalls = 0;
  var registerCalls = 0;
  var unregisterCalls = 0;
  final registeredRevisions = <int>[];
  final unregisteredRevisions = <int>[];

  @override
  Future<PushPreferences> getPreferences() async {
    getCalls++;
    return preferences;
  }

  @override
  Future<PushPreferences> updatePreferences(PushPreferences preferences) async {
    updateCalls++;
    if (failUpdates) {
      throw StateError('save failed');
    }
    return this.preferences = preferences;
  }

  @override
  Future<void> registerDevice({
    required String installationId,
    required int clientRevision,
    required KisouPushPlatform platform,
    required String fcmToken,
    required String appVersion,
  }) async {
    registerCalls++;
    registeredRevisions.add(clientRevision);
  }

  @override
  Future<void> unregisterDevice({
    required String installationId,
    required int clientRevision,
    bool suppressAuthRecovery = false,
  }) async {
    unregisterCalls++;
    unregisteredRevisions.add(clientRevision);
  }
}
