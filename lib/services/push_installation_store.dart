import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../config/push_config.dart';

enum PushDeviceMutationType { register, unregister }

class PushDeviceMutation {
  const PushDeviceMutation._({
    required this.type,
    required this.revision,
    this.platform,
    this.tokenHash,
    this.appVersion,
  });

  const PushDeviceMutation.register({
    required int revision,
    required KisouPushPlatform platform,
    required String tokenHash,
    required String appVersion,
  }) : this._(
         type: PushDeviceMutationType.register,
         revision: revision,
         platform: platform,
         tokenHash: tokenHash,
         appVersion: appVersion,
       );

  const PushDeviceMutation.unregister({required int revision})
    : this._(type: PushDeviceMutationType.unregister, revision: revision);

  final PushDeviceMutationType type;
  final int revision;
  final KisouPushPlatform? platform;
  final String? tokenHash;
  final String? appVersion;

  bool matchesRegister({
    required KisouPushPlatform platform,
    required String tokenHash,
    required String appVersion,
  }) {
    return type == PushDeviceMutationType.register &&
        this.platform == platform &&
        this.tokenHash == tokenHash &&
        this.appVersion == appVersion;
  }
}

class PushInstallationRecord {
  const PushInstallationRecord({
    required this.installationId,
    required this.revision,
    required this.activeRevision,
    required this.registeredPlatform,
    required this.registeredTokenHash,
    required this.registeredAppVersion,
    required this.pendingMutation,
    required this.platformCleanupRequired,
  });

  factory PushInstallationRecord.create(String installationId) {
    if (!_uuidV4Pattern.hasMatch(installationId)) {
      throw const FormatException('Invalid push installation identifier.');
    }
    return PushInstallationRecord(
      installationId: installationId,
      revision: 0,
      activeRevision: null,
      registeredPlatform: null,
      registeredTokenHash: null,
      registeredAppVersion: null,
      pendingMutation: null,
      platformCleanupRequired: false,
    );
  }

  factory PushInstallationRecord.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 && decoded['version'] != 2) {
      throw const FormatException('Invalid push installation record.');
    }
    final version = decoded['version'] as int;
    const version1Keys = {
      'version',
      'installation_id',
      'client_revision',
      'active_revision',
      'registered_platform',
      'registered_token_hash',
      'registered_app_version',
      'pending_mutation',
    };
    const version2Keys = {...version1Keys, 'platform_cleanup_required'};
    if (decoded.keys
        .toSet()
        .difference(version == 1 ? version1Keys : version2Keys)
        .isNotEmpty) {
      throw const FormatException('Unexpected push installation metadata.');
    }
    final installationId = decoded['installation_id'];
    final revision = decoded['client_revision'];
    final activeRevision = decoded['active_revision'];
    if (installationId is! String ||
        !_uuidV4Pattern.hasMatch(installationId) ||
        revision is! int ||
        revision < 0 ||
        revision > maxClientRevision ||
        activeRevision != null &&
            (activeRevision is! int ||
                activeRevision < 1 ||
                activeRevision > revision)) {
      throw const FormatException('Invalid push installation metadata.');
    }
    final registeredPlatform = _decodeOptionalPlatform(
      decoded['registered_platform'],
    );
    final registeredTokenHash = decoded['registered_token_hash'];
    final registeredAppVersion = decoded['registered_app_version'];
    final registeredFields = [
      registeredPlatform,
      registeredTokenHash,
      registeredAppVersion,
    ];
    final registeredFieldsConsistent = activeRevision == null
        ? registeredFields.every((value) => value == null)
        : registeredPlatform != null &&
              registeredTokenHash is String &&
              _sha256Pattern.hasMatch(registeredTokenHash) &&
              registeredAppVersion is String &&
              _validAppVersion(registeredAppVersion);
    if (!registeredFieldsConsistent) {
      throw const FormatException('Invalid active push registration.');
    }
    final pending = _decodePendingMutation(decoded['pending_mutation']);
    if (pending != null &&
        (pending.revision != revision ||
            pending.type == PushDeviceMutationType.unregister &&
                activeRevision != null)) {
      throw const FormatException('Invalid pending push mutation.');
    }
    final encodedPlatformCleanup = decoded['platform_cleanup_required'];
    if (version == 2 && encodedPlatformCleanup is! bool) {
      throw const FormatException('Invalid platform cleanup marker.');
    }
    // Version 1 predates the platform marker. Conservatively migrate every
    // server-active/pending record so a later disabled build cannot leave an
    // auto-init value or token created by that older build.
    final platformCleanupRequired = version == 1
        ? activeRevision != null || pending != null
        : encodedPlatformCleanup as bool;
    return PushInstallationRecord(
      installationId: installationId,
      revision: revision,
      activeRevision: activeRevision as int?,
      registeredPlatform: registeredPlatform,
      registeredTokenHash: registeredTokenHash as String?,
      registeredAppVersion: registeredAppVersion as String?,
      pendingMutation: pending,
      platformCleanupRequired: platformCleanupRequired,
    );
  }

  static const maxClientRevision = 0x7fffffffffffffff;

  final String installationId;
  final int revision;
  final int? activeRevision;
  final KisouPushPlatform? registeredPlatform;
  final String? registeredTokenHash;
  final String? registeredAppVersion;
  final PushDeviceMutation? pendingMutation;
  final bool platformCleanupRequired;

  bool get requiresServerCleanup =>
      activeRevision != null || pendingMutation != null;

  bool get requiresCleanup => platformCleanupRequired || requiresServerCleanup;

  bool allowsRoutingRevision(int clientRevision) {
    if (pendingMutation?.type == PushDeviceMutationType.unregister) {
      return false;
    }
    return activeRevision == clientRevision ||
        pendingMutation?.type == PushDeviceMutationType.register &&
            pendingMutation?.revision == clientRevision;
  }

  PushInstallationRecord withPlatformCleanupRequired(bool value) {
    if (platformCleanupRequired == value) {
      return this;
    }
    return PushInstallationRecord(
      installationId: installationId,
      revision: revision,
      activeRevision: activeRevision,
      registeredPlatform: registeredPlatform,
      registeredTokenHash: registeredTokenHash,
      registeredAppVersion: registeredAppVersion,
      pendingMutation: pendingMutation,
      platformCleanupRequired: value,
    );
  }

  bool registrationMatches({
    required KisouPushPlatform platform,
    required String tokenHash,
    required String appVersion,
  }) {
    return pendingMutation == null &&
        activeRevision != null &&
        registeredPlatform == platform &&
        registeredTokenHash == tokenHash &&
        registeredAppVersion == appVersion;
  }

  PushInstallationRecord beginRegister({
    required KisouPushPlatform platform,
    required String tokenHash,
    required String appVersion,
  }) {
    final pending = pendingMutation;
    if (pending?.matchesRegister(
          platform: platform,
          tokenHash: tokenHash,
          appVersion: appVersion,
        ) ==
        true) {
      return this;
    }
    final nextRevision = _nextRevision;
    return PushInstallationRecord(
      installationId: installationId,
      revision: nextRevision,
      activeRevision: activeRevision,
      registeredPlatform: registeredPlatform,
      registeredTokenHash: registeredTokenHash,
      registeredAppVersion: registeredAppVersion,
      pendingMutation: PushDeviceMutation.register(
        revision: nextRevision,
        platform: platform,
        tokenHash: tokenHash,
        appVersion: appVersion,
      ),
      platformCleanupRequired: true,
    );
  }

  PushInstallationRecord completeRegister() {
    final pending = pendingMutation;
    if (pending == null || pending.type != PushDeviceMutationType.register) {
      throw StateError('No push registration is pending.');
    }
    return PushInstallationRecord(
      installationId: installationId,
      revision: revision,
      activeRevision: revision,
      registeredPlatform: pending.platform,
      registeredTokenHash: pending.tokenHash,
      registeredAppVersion: pending.appVersion,
      pendingMutation: null,
      platformCleanupRequired: platformCleanupRequired,
    );
  }

  PushInstallationRecord beginUnregister() {
    if (pendingMutation?.type == PushDeviceMutationType.unregister) {
      return this;
    }
    if (activeRevision == null && pendingMutation == null) {
      return this;
    }
    final nextRevision = _nextRevision;
    return PushInstallationRecord(
      installationId: installationId,
      revision: nextRevision,
      activeRevision: null,
      registeredPlatform: null,
      registeredTokenHash: null,
      registeredAppVersion: null,
      pendingMutation: PushDeviceMutation.unregister(revision: nextRevision),
      platformCleanupRequired: platformCleanupRequired,
    );
  }

  PushInstallationRecord completeUnregister() {
    if (pendingMutation?.type != PushDeviceMutationType.unregister) {
      throw StateError('No push unregistration is pending.');
    }
    return PushInstallationRecord(
      installationId: installationId,
      revision: revision,
      activeRevision: null,
      registeredPlatform: null,
      registeredTokenHash: null,
      registeredAppVersion: null,
      pendingMutation: null,
      platformCleanupRequired: platformCleanupRequired,
    );
  }

  int get _nextRevision {
    if (revision >= maxClientRevision) {
      throw StateError('Push client revision is exhausted.');
    }
    return revision + 1;
  }

  String encode() {
    final pending = pendingMutation;
    return jsonEncode({
      'version': 2,
      'installation_id': installationId,
      'client_revision': revision,
      'platform_cleanup_required': platformCleanupRequired,
      if (activeRevision != null) 'active_revision': activeRevision,
      if (registeredPlatform != null)
        'registered_platform': registeredPlatform!.name,
      if (registeredTokenHash != null)
        'registered_token_hash': registeredTokenHash,
      if (registeredAppVersion != null)
        'registered_app_version': registeredAppVersion,
      if (pending != null)
        'pending_mutation': {
          'type': pending.type.name,
          'client_revision': pending.revision,
          if (pending.platform != null) 'platform': pending.platform!.name,
          if (pending.tokenHash != null) 'token_hash': pending.tokenHash,
          if (pending.appVersion != null) 'app_version': pending.appVersion,
        },
    });
  }
}

class PushInstallationSnapshot {
  const PushInstallationSnapshot({
    required this.record,
    required this.accountGeneration,
  });

  final PushInstallationRecord? record;
  final int accountGeneration;
}

typedef PushRegisterSender =
    Future<void> Function(
      String installationId,
      int clientRevision,
      KisouPushPlatform platform,
      String appVersion,
    );
typedef PushUnregisterSender =
    Future<void> Function(String installationId, int clientRevision);

class PreparedPushRegistration {
  const PreparedPushRegistration({
    required this.platform,
    required this.tokenHash,
    required this.appVersion,
    required this.send,
  });

  final KisouPushPlatform platform;
  final String tokenHash;
  final String appVersion;
  final PushRegisterSender send;
}

class PushInstallationStore {
  PushInstallationStore({
    FlutterSecureStorage? storage,
    String Function()? installationIdFactory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _installationIdFactory = installationIdFactory ?? const Uuid().v4;

  static const storageKey = 'push_installation_v1';
  static final _iOptions = IOSOptions(
    accountName: ApiConfig.secureStorageService,
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );
  static const _aOptions = AndroidOptions(resetOnError: false);
  static final _lifecycleLock = Lock();
  static var _accountGeneration = 0;

  final FlutterSecureStorage _storage;
  final String Function() _installationIdFactory;

  Future<PushInstallationSnapshot> readSnapshot() {
    return _lifecycleLock.synchronized(() async {
      return PushInstallationSnapshot(
        record: await _readUnlocked(),
        accountGeneration: _accountGeneration,
      );
    });
  }

  Future<PushInstallationRecord?> read() async {
    return (await readSnapshot()).record;
  }

  /// Persists the platform rollback boundary before any Firebase call can turn
  /// auto-init on or create/read a token.
  Future<void> markPlatformCleanupRequiredIfCurrent({
    required int accountGeneration,
  }) {
    return _lifecycleLock.synchronized(() async {
      _requireCurrent(accountGeneration);
      final record =
          (await _readUnlocked() ??
                  PushInstallationRecord.create(_installationIdFactory()))
              .withPlatformCleanupRequired(true);
      await _writeUnlocked(record);
    });
  }

  /// Runs the whole marker -> Firebase activation -> token/server registration
  /// sequence behind the account lifecycle barrier. [closeAccount] invalidates
  /// the generation immediately and then waits behind this transaction, so any
  /// platform state created by an in-flight prepare is always cleaned after it.
  Future<void> registerPreparedIfCurrent({
    required int accountGeneration,
    required Future<PreparedPushRegistration> Function() prepare,
  }) {
    return _lifecycleLock.synchronized(() async {
      _requireCurrent(accountGeneration);
      var record =
          await _readUnlocked() ??
          PushInstallationRecord.create(_installationIdFactory());
      record = record.withPlatformCleanupRequired(true);
      await _writeUnlocked(record);
      _requireCurrent(accountGeneration);
      final registration = await prepare();
      _requireCurrent(accountGeneration);
      _validateRegistration(
        tokenHash: registration.tokenHash,
        appVersion: registration.appVersion,
      );
      await _registerUnlocked(
        record: record,
        platform: registration.platform,
        tokenHash: registration.tokenHash,
        appVersion: registration.appVersion,
        send: registration.send,
      );
    });
  }

  /// Clears only the platform marker after both auto-init disablement and token
  /// deletion have succeeded. Server registration state remains independent.
  Future<PushInstallationRecord?> completePlatformCleanup() {
    return _lifecycleLock.synchronized(() async {
      var record = await _readUnlocked();
      if (record?.platformCleanupRequired == true) {
        record = record!.withPlatformCleanupRequired(false);
        await _writeUnlocked(record);
      }
      return record;
    });
  }

  Future<void> registerIfCurrent({
    required int accountGeneration,
    required KisouPushPlatform platform,
    required String tokenHash,
    required String appVersion,
    required PushRegisterSender send,
  }) {
    _validateRegistration(tokenHash: tokenHash, appVersion: appVersion);
    return _lifecycleLock.synchronized(() async {
      _requireCurrent(accountGeneration);
      var record =
          await _readUnlocked() ??
          PushInstallationRecord.create(_installationIdFactory());
      if (!record.platformCleanupRequired) {
        record = record.withPlatformCleanupRequired(true);
        await _writeUnlocked(record);
      }
      _requireCurrent(accountGeneration);
      await _registerUnlocked(
        record: record,
        platform: platform,
        tokenHash: tokenHash,
        appVersion: appVersion,
        send: send,
      );
    });
  }

  Future<void> _registerUnlocked({
    required PushInstallationRecord record,
    required KisouPushPlatform platform,
    required String tokenHash,
    required String appVersion,
    required PushRegisterSender send,
  }) async {
    if (record.registrationMatches(
      platform: platform,
      tokenHash: tokenHash,
      appVersion: appVersion,
    )) {
      // Refresh the server's last-seen timestamp on every authenticated app
      // startup. The same revision + semantic payload is an idempotent replay.
      await send(
        record.installationId,
        record.activeRevision!,
        record.registeredPlatform!,
        record.registeredAppVersion!,
      );
      return;
    }
    final pendingRecord = record.beginRegister(
      platform: platform,
      tokenHash: tokenHash,
      appVersion: appVersion,
    );
    await _writeUnlocked(pendingRecord);
    final pending = pendingRecord.pendingMutation!;
    await send(
      pendingRecord.installationId,
      pending.revision,
      pending.platform!,
      pending.appVersion!,
    );
    // A close may already have invalidated this generation while the network
    // call held the lock. Completing here is safe: close runs next and writes
    // a strictly higher durable unregister revision.
    await _writeUnlocked(pendingRecord.completeRegister());
  }

  /// Invalidates queued account work synchronously, drains an in-flight
  /// register, writes an unregister intent before the request, and preserves
  /// the installation UUID/revision as install-scoped replay protection.
  Future<PushInstallationSnapshot> closeAccount({
    required PushUnregisterSender send,
    required Future<void> Function() deletePlatformToken,
  }) {
    _accountGeneration++;
    return _lifecycleLock.synchronized(() async {
      PushInstallationRecord? record;
      var corruptRecord = false;
      Object? corruptError;
      StackTrace? corruptStackTrace;
      var platformCleanupNeeded = false;
      Future<bool>? serverAttempt;
      Future<bool>? platformAttempt;
      Object? localError;
      StackTrace? localStackTrace;
      try {
        record = await _readUnlocked();
        if (record != null) {
          platformCleanupNeeded = record.platformCleanupRequired;
          record = record.beginUnregister();
        }
        if (record?.pendingMutation?.type ==
            PushDeviceMutationType.unregister) {
          // This write is the security boundary: no unregister request or
          // later-account work may proceed without a durable higher revision.
          await _writeUnlocked(record!);
          serverAttempt = _attemptCleanup(
            () => send(record!.installationId, record.revision),
          );
        }
      } on PushInstallationCorruptException catch (error, stackTrace) {
        // The key's presence means a previous build may have activated
        // Firebase even though its installation/revision can no longer be
        // trusted. No server mutation is safe, but platform identity cleanup
        // is mandatory before replacing the corrupt value.
        corruptRecord = true;
        corruptError = error;
        corruptStackTrace = stackTrace;
        platformCleanupNeeded = true;
      } catch (error, stackTrace) {
        localError = error;
        localStackTrace = stackTrace;
      }
      if (platformCleanupNeeded) {
        // Start independently from server unregister. A slow/offline backend
        // must never postpone local token/FID deletion.
        platformAttempt = _attemptCleanup(deletePlatformToken);
      }
      final unregistered = await (serverAttempt ?? Future<bool>.value(false));
      final platformCleaned =
          await (platformAttempt ?? Future<bool>.value(false));
      if (corruptRecord) {
        if (!platformCleaned) {
          Error.throwWithStackTrace(corruptError!, corruptStackTrace!);
        }
        // Replace only after auto-init, the FCM token, and the Firebase
        // Installation ID are all removed. Writing directly over the same
        // secure key avoids a delete-then-write crash gap; a failed write
        // leaves the existing corrupt value as the retry marker.
        record = PushInstallationRecord.create(_installationIdFactory());
        await _writeUnlocked(record);
        return PushInstallationSnapshot(
          record: record,
          accountGeneration: _accountGeneration,
        );
      }
      if (localError == null && (unregistered || platformCleaned)) {
        try {
          if (unregistered &&
              record?.pendingMutation?.type ==
                  PushDeviceMutationType.unregister) {
            record = record!.completeUnregister();
          }
          if (platformCleaned && record?.platformCleanupRequired == true) {
            record = record!.withPlatformCleanupRequired(false);
          }
          await _writeUnlocked(record!);
        } catch (error, stackTrace) {
          localError = error;
          localStackTrace = stackTrace;
        }
      }
      if (localError != null) {
        Error.throwWithStackTrace(localError, localStackTrace!);
      }
      return PushInstallationSnapshot(
        record: record,
        accountGeneration: _accountGeneration,
      );
    });
  }

  Future<bool> _attemptCleanup(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PushInstallationRecord?> _readUnlocked() async {
    try {
      final encoded = await _storage.read(
        key: storageKey,
        iOptions: _iOptions,
        aOptions: _aOptions,
      );
      if (encoded == null || encoded.isEmpty) {
        return null;
      }
      return PushInstallationRecord.decode(encoded);
    } on FormatException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const PushInstallationCorruptException(),
        stackTrace,
      );
    } on TypeError catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const PushInstallationCorruptException(),
        stackTrace,
      );
    } on PlatformException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const PushInstallationReadException(),
        stackTrace,
      );
    }
  }

  Future<void> _writeUnlocked(PushInstallationRecord record) {
    return _storage.write(
      key: storageKey,
      value: record.encode(),
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
  }

  void _requireCurrent(int generation) {
    if (generation != _accountGeneration) {
      throw const StalePushAccountOperationException();
    }
  }

  void _validateRegistration({
    required String tokenHash,
    required String appVersion,
  }) {
    if (!_sha256Pattern.hasMatch(tokenHash) || !_validAppVersion(appVersion)) {
      throw const FormatException('Invalid push registration metadata.');
    }
  }
}

class PushInstallationReadException implements Exception {
  const PushInstallationReadException();
}

class PushInstallationCorruptException extends PushInstallationReadException {
  const PushInstallationCorruptException();
}

class StalePushAccountOperationException implements Exception {
  const StalePushAccountOperationException();
}

KisouPushPlatform? _decodeOptionalPlatform(Object? value) {
  return switch (value) {
    null => null,
    'android' => KisouPushPlatform.android,
    'ios' => KisouPushPlatform.ios,
    _ => throw const FormatException('Invalid push platform.'),
  };
}

PushDeviceMutation? _decodePendingMutation(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid pending push mutation.');
  }
  final revision = value['client_revision'];
  if (revision is! int || revision < 1) {
    throw const FormatException('Invalid pending push revision.');
  }
  if (value['type'] == 'unregister') {
    if (value.length != 2) {
      throw const FormatException('Invalid unregister mutation.');
    }
    return PushDeviceMutation.unregister(revision: revision);
  }
  final platform = _decodeOptionalPlatform(value['platform']);
  final tokenHash = value['token_hash'];
  final appVersion = value['app_version'];
  if (value['type'] != 'register' ||
      value.length != 5 ||
      platform == null ||
      tokenHash is! String ||
      !_sha256Pattern.hasMatch(tokenHash) ||
      appVersion is! String ||
      !_validAppVersion(appVersion)) {
    throw const FormatException('Invalid register mutation.');
  }
  return PushDeviceMutation.register(
    revision: revision,
    platform: platform,
    tokenHash: tokenHash,
    appVersion: appVersion,
  );
}

bool _validAppVersion(String value) {
  return value.isNotEmpty &&
      value.length <= 64 &&
      value.trim() == value &&
      !value.contains(RegExp(r'[\x00-\x1f\x7f]'));
}

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
