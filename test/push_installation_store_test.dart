import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/push_config.dart';
import 'package:kisou_app/models/push_notification.dart';
import 'package:kisou_app/providers/push_provider.dart';
import 'package:kisou_app/services/push_installation_store.dart';
import 'package:kisou_app/services/push_messaging_gateway.dart';
import 'package:kisou_app/services/push_service.dart';

const _installationId = '123e4567-e89b-42d3-a456-426614174000';
const _tokenHashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _tokenHashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registration intent is durable, replay-safe, and stores no raw token',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final generation = (await store.readSnapshot()).accountGeneration;
      final revisions = <int>[];
      var loseFirstResponse = true;

      Future<void> send(
        String installationId,
        int clientRevision,
        KisouPushPlatform platform,
        String appVersion,
      ) async {
        expect(installationId, _installationId);
        expect(platform, KisouPushPlatform.android);
        expect(appVersion, '1.0.0+1');
        revisions.add(clientRevision);
        if (loseFirstResponse) {
          loseFirstResponse = false;
          throw StateError('response lost');
        }
      }

      await expectLater(
        store.registerIfCurrent(
          accountGeneration: generation,
          platform: KisouPushPlatform.android,
          tokenHash: _tokenHashA,
          appVersion: '1.0.0+1',
          send: send,
        ),
        throwsStateError,
      );
      final pending = await store.read();
      expect(pending?.revision, 1);
      expect(pending?.pendingMutation?.revision, 1);
      expect(pending?.requiresCleanup, isTrue);
      expect(pending?.allowsRoutingRevision(1), isTrue);
      expect(pending?.allowsRoutingRevision(2), isFalse);

      await store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashA,
        appVersion: '1.0.0+1',
        send: send,
      );
      final active = await store.read();
      expect(active?.activeRevision, 1);
      expect(active?.pendingMutation, isNull);
      expect(revisions, [1, 1]);
      expect(active?.allowsRoutingRevision(1), isTrue);
      expect(storage.value, contains(_tokenHashA));
      expect(storage.value, isNot(contains('raw-fcm-token')));

      // Authenticated startup refreshes last-seen using the exact same revision.
      await store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashA,
        appVersion: '1.0.0+1',
        send: send,
      );
      expect(revisions, [1, 1, 1]);

      await store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashB,
        appVersion: '1.0.0+1',
        send: send,
      );
      expect((await store.read())?.activeRevision, 2);
      expect(revisions.last, 2);
    },
  );

  test(
    'account close wins over in-flight and queued token refreshes',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final generation = (await store.readSnapshot()).accountGeneration;
      final registerStarted = Completer<void>();
      final allowRegister = Completer<void>();
      final events = <String>[];

      final inFlight = store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashA,
        appVersion: '1.0.0+1',
        send: (_, revision, _, _) async {
          events.add('register:$revision');
          registerStarted.complete();
          await allowRegister.future;
        },
      );
      await registerStarted.future;

      var tokenDeleteCalls = 0;
      final close = store.closeAccount(
        send: (_, revision) async => events.add('unregister:$revision'),
        deletePlatformToken: () async => tokenDeleteCalls++,
      );
      final staleRefresh = store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashB,
        appVersion: '1.0.0+1',
        send: (_, revision, _, _) async => events.add('stale:$revision'),
      );

      allowRegister.complete();
      await inFlight;
      final closed = await close;
      await expectLater(
        staleRefresh,
        throwsA(isA<StalePushAccountOperationException>()),
      );

      expect(events, ['register:1', 'unregister:2']);
      expect(tokenDeleteCalls, 1);
      expect(closed.record?.activeRevision, isNull);
      expect(closed.record?.revision, 2);
      expect(closed.record?.requiresCleanup, isFalse);
    },
  );

  test(
    'platform cleanup marker precedes every Firebase activation attempt',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final gateway = _ActivationCrashGateway();
      final manager = PushAccountManager(
        store: store,
        messaging: gateway,
        api: _NoopPushApi(),
        platform: KisouPushPlatform.android,
        appVersionFactory: () async => '1.0.0+1',
      );
      final generation = await manager.readAccountGeneration();

      await expectLater(
        manager.register(accountGeneration: generation),
        throwsStateError,
      );

      final afterCrash = await store.read();
      expect(gateway.activationAttempted, isTrue);
      expect(afterCrash?.platformCleanupRequired, isTrue);
      expect(afterCrash?.revision, 0);
      expect(afterCrash?.requiresServerCleanup, isFalse);

      // A disabled-build cleanup failure cannot erase the marker.
      await store.closeAccount(
        send: (_, _) async => fail('there is no server registration'),
        deletePlatformToken: () async =>
            throw StateError('native cleanup failed'),
      );
      expect((await store.read())?.platformCleanupRequired, isTrue);

      await store.closeAccount(
        send: (_, _) async => fail('there is no server registration'),
        deletePlatformToken: () async {},
      );
      expect((await store.read())?.requiresCleanup, isFalse);
    },
  );

  test(
    'close waits behind platform activation and always cleans its identity',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final gateway = _BarrierGateway();
      final api = _NoopPushApi();
      final manager = PushAccountManager(
        store: store,
        messaging: gateway,
        api: api,
        platform: KisouPushPlatform.android,
        appVersionFactory: () async => '1.0.0+1',
      );
      final generation = await manager.readAccountGeneration();

      final registration = manager.register(accountGeneration: generation);
      await gateway.prepareStarted.future;
      final close = manager.closeAccount();
      gateway.allowPrepare.complete();

      await expectLater(
        registration,
        throwsA(isA<StalePushAccountOperationException>()),
      );
      await close;

      expect(api.registerCalls, 0);
      expect(api.unregisterCalls, 0);
      expect(gateway.deleteTokenCount, 1);
      expect(gateway.deleteInstallationCount, 1);
      expect((await store.read())?.requiresCleanup, isFalse);
    },
  );

  test('token cleanup failure survives successful server unregister', () async {
    final storage = _MemorySecureStorage();
    final store = PushInstallationStore(
      storage: storage,
      installationIdFactory: () => _installationId,
    );
    final generation = (await store.readSnapshot()).accountGeneration;
    await store.registerIfCurrent(
      accountGeneration: generation,
      platform: KisouPushPlatform.android,
      tokenHash: _tokenHashA,
      appVersion: '1.0.0+1',
      send: (_, _, _, _) async {},
    );

    await store.closeAccount(
      send: (_, _) async {},
      deletePlatformToken: () async =>
          throw StateError('native cleanup failed'),
    );

    final record = await store.read();
    expect(record?.requiresServerCleanup, isFalse);
    expect(record?.platformCleanupRequired, isTrue);
    expect(record?.requiresCleanup, isTrue);
  });

  test('account manager reports incomplete platform cleanup', () async {
    final storage = _MemorySecureStorage();
    final store = PushInstallationStore(
      storage: storage,
      installationIdFactory: () => _installationId,
    );
    final generation = (await store.readSnapshot()).accountGeneration;
    await store.registerIfCurrent(
      accountGeneration: generation,
      platform: KisouPushPlatform.android,
      tokenHash: _tokenHashA,
      appVersion: '1.0.0+1',
      send: (_, _, _, _) async {},
    );
    final manager = PushAccountManager(
      store: store,
      messaging: _FailingCleanupGateway(),
      api: _NoopPushApi(),
      platform: KisouPushPlatform.android,
      appVersionFactory: () async => '1.0.0+1',
    );

    await expectLater(
      manager.closeAccount(),
      throwsA(
        isA<PushAccountCloseIncompleteException>().having(
          (error) => error.snapshot.record?.platformCleanupRequired,
          'platform marker',
          isTrue,
        ),
      ),
    );
  });

  test(
    'platform cleanup starts while server unregister is still in flight',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final generation = (await store.readSnapshot()).accountGeneration;
      await store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashA,
        appVersion: '1.0.0+1',
        send: (_, _, _, _) async {},
      );
      final serverStarted = Completer<void>();
      final allowServer = Completer<void>();
      final platformStarted = Completer<void>();
      var closeCompleted = false;

      final close = store
          .closeAccount(
            send: (_, _) async {
              serverStarted.complete();
              await allowServer.future;
            },
            deletePlatformToken: () async {
              platformStarted.complete();
            },
          )
          .whenComplete(() => closeCompleted = true);

      await serverStarted.future;
      await platformStarted.future;
      expect(closeCompleted, isFalse);
      expect(PushInstallationRecord.decode(storage.value!).revision, 2);

      allowServer.complete();
      await close;
      expect(closeCompleted, isTrue);
      expect((await store.read())?.requiresCleanup, isFalse);
    },
  );

  test('legacy active records conservatively acquire a platform marker', () {
    final legacy = PushInstallationRecord.decode(
      '{"version":1,"installation_id":"$_installationId",'
      '"client_revision":1,"active_revision":1,'
      '"registered_platform":"android",'
      '"registered_token_hash":"$_tokenHashA",'
      '"registered_app_version":"1.0.0+1"}',
    );

    expect(legacy.platformCleanupRequired, isTrue);
    expect(legacy.requiresCleanup, isTrue);
    expect(
      PushInstallationRecord.decode(legacy.encode()).requiresCleanup,
      isTrue,
    );
  });

  test(
    'failed unregister remains a higher durable tombstone for retry',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final generation = (await store.readSnapshot()).accountGeneration;
      await store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashA,
        appVersion: '1.0.0+1',
        send: (_, _, _, _) async {},
      );

      await store.closeAccount(
        send: (_, _) async => throw StateError('offline'),
        deletePlatformToken: () async {},
      );
      final pending = await store.read();
      expect(pending?.revision, 2);
      expect(pending?.pendingMutation?.type, PushDeviceMutationType.unregister);
      expect(pending?.activeRevision, isNull);
      expect(pending?.requiresCleanup, isTrue);
      expect(pending?.allowsRoutingRevision(1), isFalse);
      expect(pending?.allowsRoutingRevision(2), isFalse);

      final retryRevisions = <int>[];
      await store.closeAccount(
        send: (_, revision) async => retryRevisions.add(revision),
        deletePlatformToken: () async {},
      );
      expect(retryRevisions, [2]);
      expect((await store.read())?.requiresCleanup, isFalse);
    },
  );

  test('corrupt secure metadata fails closed', () async {
    final store = PushInstallationStore(
      storage: _MemorySecureStorage(value: '{corrupt'),
    );

    await expectLater(
      store.read(),
      throwsA(isA<PushInstallationCorruptException>()),
    );
  });

  test(
    'corrupt metadata is replaced only after conservative platform cleanup',
    () async {
      final storage = _MemorySecureStorage(value: '{corrupt');
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      var unregisterCalls = 0;
      var platformCleanupCalls = 0;

      final closed = await store.closeAccount(
        send: (_, _) async => unregisterCalls++,
        deletePlatformToken: () async => platformCleanupCalls++,
      );

      expect(unregisterCalls, 0);
      expect(platformCleanupCalls, 1);
      expect(closed.record?.installationId, _installationId);
      expect(closed.record?.revision, 0);
      expect(closed.record?.requiresCleanup, isFalse);
      expect(PushInstallationRecord.decode(storage.value!).revision, 0);
    },
  );

  test(
    'corrupt metadata survives platform cleanup or recovery-write failure',
    () async {
      const corrupt = '{corrupt';
      final cleanupFailureStorage = _MemorySecureStorage(value: corrupt);
      final cleanupFailureStore = PushInstallationStore(
        storage: cleanupFailureStorage,
        installationIdFactory: () => _installationId,
      );

      await expectLater(
        cleanupFailureStore.closeAccount(
          send: (_, _) async => fail('corrupt state has no safe server ID'),
          deletePlatformToken: () async =>
              throw StateError('platform cleanup failed'),
        ),
        throwsA(isA<PushInstallationCorruptException>()),
      );
      expect(cleanupFailureStorage.value, corrupt);

      final writeFailureStorage = _MemorySecureStorage(value: corrupt)
        ..failWrites = true;
      final writeFailureStore = PushInstallationStore(
        storage: writeFailureStorage,
        installationIdFactory: () => _installationId,
      );
      var platformCleanupCalls = 0;

      await expectLater(
        writeFailureStore.closeAccount(
          send: (_, _) async => fail('corrupt state has no safe server ID'),
          deletePlatformToken: () async => platformCleanupCalls++,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(platformCleanupCalls, 1);
      expect(writeFailureStorage.value, corrupt);
    },
  );

  test(
    'unknown secure-storage read failure never guesses or erases state',
    () async {
      final storage = _MemorySecureStorage(value: '{corrupt')..failReads = true;
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      var platformCleanupCalls = 0;

      await expectLater(
        store.closeAccount(
          send: (_, _) async => fail('no trusted installation ID'),
          deletePlatformToken: () async => platformCleanupCalls++,
        ),
        throwsA(isA<PushInstallationReadException>()),
      );

      expect(platformCleanupCalls, 0);
      expect(storage.value, '{corrupt');
    },
  );

  test(
    'failed durable unregister write still attempts platform token deletion',
    () async {
      final storage = _MemorySecureStorage();
      final store = PushInstallationStore(
        storage: storage,
        installationIdFactory: () => _installationId,
      );
      final generation = (await store.readSnapshot()).accountGeneration;
      await store.registerIfCurrent(
        accountGeneration: generation,
        platform: KisouPushPlatform.android,
        tokenHash: _tokenHashA,
        appVersion: '1.0.0+1',
        send: (_, _, _, _) async {},
      );
      storage.failWrites = true;
      var unregisterCalls = 0;
      var tokenDeleteCalls = 0;

      await expectLater(
        store.closeAccount(
          send: (_, _) async => unregisterCalls++,
          deletePlatformToken: () async => tokenDeleteCalls++,
        ),
        throwsA(isA<PlatformException>()),
      );

      expect(unregisterCalls, 0);
      expect(tokenDeleteCalls, 1);
    },
  );

  test(
    'never-opted-in and server-only cleanup never touch Firebase identity',
    () async {
      final freshStorage = _MemorySecureStorage();
      final freshStore = PushInstallationStore(storage: freshStorage);
      var freshPlatformCalls = 0;
      await freshStore.closeAccount(
        send: (_, _) async => fail('fresh install has no server state'),
        deletePlatformToken: () async => freshPlatformCalls++,
      );
      expect(freshPlatformCalls, 0);
      expect(await freshStore.read(), isNull);

      final serverOnlyStorage = _MemorySecureStorage(
        value:
            '{"version":2,"installation_id":"$_installationId",'
            '"client_revision":1,"platform_cleanup_required":false,'
            '"pending_mutation":{"type":"unregister","client_revision":1}}',
      );
      final serverOnlyStore = PushInstallationStore(storage: serverOnlyStorage);
      final unregistered = <int>[];
      var serverOnlyPlatformCalls = 0;
      await serverOnlyStore.closeAccount(
        send: (_, revision) async => unregistered.add(revision),
        deletePlatformToken: () async => serverOnlyPlatformCalls++,
      );
      expect(unregistered, [1]);
      expect(serverOnlyPlatformCalls, 0);
      expect((await serverOnlyStore.read())?.requiresCleanup, isFalse);
    },
  );
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage({this.value});

  String? value;
  bool failReads = false;
  bool failWrites = false;

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
    if (failReads) {
      throw PlatformException(code: 'read-failed');
    }
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
    if (failWrites) {
      throw PlatformException(code: 'write-failed');
    }
    this.value = value;
  }
}

class _ActivationCrashGateway extends MemoryPushMessagingGateway {
  var activationAttempted = false;

  @override
  Future<void> prepareNotificationPresentation() async {
    activationAttempted = true;
    autoInitEnabled = true;
    throw StateError('process stopped after native activation');
  }
}

class _BarrierGateway extends MemoryPushMessagingGateway {
  final prepareStarted = Completer<void>();
  final allowPrepare = Completer<void>();

  @override
  Future<void> prepareNotificationPresentation() async {
    autoInitEnabled = true;
    prepareStarted.complete();
    await allowPrepare.future;
  }
}

class _FailingCleanupGateway extends MemoryPushMessagingGateway {
  @override
  Future<void> disableAndDeleteToken() async {
    throw StateError('native cleanup failed');
  }
}

class _NoopPushApi implements PushApiGateway {
  var registerCalls = 0;
  var unregisterCalls = 0;

  @override
  Future<PushPreferences> getPreferences() async => PushPreferences.defaults;

  @override
  Future<void> registerDevice({
    required String installationId,
    required int clientRevision,
    required KisouPushPlatform platform,
    required String fcmToken,
    required String appVersion,
  }) async {
    registerCalls++;
  }

  @override
  Future<void> unregisterDevice({
    required String installationId,
    required int clientRevision,
    bool suppressAuthRecovery = false,
  }) async {
    unregisterCalls++;
  }

  @override
  Future<PushPreferences> updatePreferences(PushPreferences preferences) async {
    return preferences;
  }
}
