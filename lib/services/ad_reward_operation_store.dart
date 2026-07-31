import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';

import '../config/ad_config.dart';
import '../config/api_config.dart';

enum AdRewardOperationStage { issuing, issued, presented }

class AdRewardOperation {
  const AdRewardOperation({
    required this.idempotencyKey,
    required this.platform,
    required this.adUnitId,
    required this.stage,
    required this.createdAt,
    this.challengeId,
    this.expiresAt,
    this.settlementExpiresAt,
  });

  factory AdRewardOperation.issuing({
    required String idempotencyKey,
    required KisouAdPlatform platform,
    required String adUnitId,
    required DateTime createdAt,
  }) {
    return AdRewardOperation(
      idempotencyKey: idempotencyKey,
      platform: platform,
      adUnitId: adUnitId,
      stage: AdRewardOperationStage.issuing,
      createdAt: createdAt,
    );
  }

  factory AdRewardOperation.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Invalid ad-reward operation.');
    }
    final idempotencyKey = decoded['idempotency_key'];
    final adUnitId = decoded['ad_unit_id'];
    final challengeId = decoded['challenge_id'];
    if (idempotencyKey is! String ||
        !_uuidV4Pattern.hasMatch(idempotencyKey) ||
        adUnitId is! String ||
        adUnitId.isEmpty ||
        challengeId != null &&
            (challengeId is! String || !_uuidPattern.hasMatch(challengeId))) {
      throw const FormatException('Invalid ad-reward operation identifiers.');
    }
    final platform = switch (decoded['platform']) {
      'android' => KisouAdPlatform.android,
      'ios' => KisouAdPlatform.ios,
      _ => throw const FormatException('Invalid ad-reward platform.'),
    };
    final stage = switch (decoded['stage']) {
      'issuing' => AdRewardOperationStage.issuing,
      'issued' => AdRewardOperationStage.issued,
      'presented' => AdRewardOperationStage.presented,
      _ => throw const FormatException('Invalid ad-reward operation stage.'),
    };
    final createdAt = _requiredUtcInstant(decoded, 'created_at');
    final expiresAt = _optionalUtcInstant(decoded, 'expires_at');
    final settlementExpiresAt = _optionalUtcInstant(
      decoded,
      'settlement_expires_at',
    );
    final challengeFields = [challengeId, expiresAt, settlementExpiresAt];
    final allChallengeFieldsAbsent = challengeFields.every(
      (value) => value == null,
    );
    final allChallengeFieldsPresent = challengeFields.every(
      (value) => value != null,
    );
    final timestampsConsistent =
        expiresAt != null &&
        settlementExpiresAt != null &&
        settlementExpiresAt.isAfter(expiresAt);
    if (stage == AdRewardOperationStage.issuing && !allChallengeFieldsAbsent ||
        stage != AdRewardOperationStage.issuing &&
            (!allChallengeFieldsPresent || !timestampsConsistent)) {
      throw const FormatException('Inconsistent ad-reward operation stage.');
    }
    return AdRewardOperation(
      idempotencyKey: idempotencyKey,
      platform: platform,
      adUnitId: adUnitId,
      stage: stage,
      createdAt: createdAt,
      challengeId: challengeId as String?,
      expiresAt: expiresAt,
      settlementExpiresAt: settlementExpiresAt,
    );
  }

  final String idempotencyKey;
  final KisouAdPlatform platform;
  final String adUnitId;
  final AdRewardOperationStage stage;
  final DateTime createdAt;
  final String? challengeId;
  final DateTime? expiresAt;
  final DateTime? settlementExpiresAt;

  /// An issue response can be replayed for at most 60 minutes by API
  /// configuration. A small skew margin prevents rotating the UUID early when
  /// the original response was lost and its exact expires_at is unknown.
  DateTime get issueReplayDeadline =>
      expiresAt ?? createdAt.add(const Duration(minutes: 61));

  AdRewardOperation withIssuedChallenge({
    required String challengeId,
    required DateTime expiresAt,
    required DateTime settlementExpiresAt,
  }) {
    return AdRewardOperation(
      idempotencyKey: idempotencyKey,
      platform: platform,
      adUnitId: adUnitId,
      stage: AdRewardOperationStage.issued,
      createdAt: createdAt,
      challengeId: challengeId,
      expiresAt: expiresAt,
      settlementExpiresAt: settlementExpiresAt,
    );
  }

  AdRewardOperation asPresented() {
    if (stage != AdRewardOperationStage.issued) {
      throw StateError('Only an issued reward operation can be presented.');
    }
    return AdRewardOperation(
      idempotencyKey: idempotencyKey,
      platform: platform,
      adUnitId: adUnitId,
      stage: AdRewardOperationStage.presented,
      createdAt: createdAt,
      challengeId: challengeId,
      expiresAt: expiresAt,
      settlementExpiresAt: settlementExpiresAt,
    );
  }

  String encode() {
    return jsonEncode({
      'version': 1,
      'idempotency_key': idempotencyKey,
      'platform': platform == KisouAdPlatform.android ? 'android' : 'ios',
      'ad_unit_id': adUnitId,
      'stage': stage.name,
      'created_at': createdAt.toIso8601String(),
      if (challengeId != null) 'challenge_id': challengeId,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (settlementExpiresAt != null)
        'settlement_expires_at': settlementExpiresAt!.toIso8601String(),
    });
  }
}

class AdRewardOperationStore {
  AdRewardOperationStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'ad_reward_operation_v1';
  static final _iOptions = IOSOptions(
    accountName: ApiConfig.secureStorageService,
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );
  static const _aOptions = AndroidOptions(resetOnError: false);
  static final _mutationLock = Lock();
  static var _accountGeneration = 0;

  final FlutterSecureStorage _storage;

  Future<AdRewardOperationSnapshot> readSnapshot() {
    return _mutationLock.synchronized(() async {
      return AdRewardOperationSnapshot(
        operation: await _readUnlocked(),
        accountGeneration: _accountGeneration,
      );
    });
  }

  Future<AdRewardOperation?> read() async {
    return (await readSnapshot()).operation;
  }

  Future<AdRewardOperation?> _readUnlocked() async {
    try {
      final encoded = await _storage.read(
        key: storageKey,
        iOptions: _iOptions,
        aOptions: _aOptions,
      );
      if (encoded == null || encoded.isEmpty) {
        return null;
      }
      return AdRewardOperation.decode(encoded);
    } on FormatException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AdRewardOperationReadException(),
        stackTrace,
      );
    } on PlatformException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AdRewardOperationReadException(),
        stackTrace,
      );
    }
  }

  Future<void> write(AdRewardOperation operation) {
    return _mutationLock.synchronized(() => _writeUnlocked(operation));
  }

  Future<void> writeIfCurrent(
    AdRewardOperation operation, {
    required int accountGeneration,
  }) {
    return _mutationLock.synchronized(() {
      _requireCurrent(accountGeneration);
      return _writeUnlocked(operation);
    });
  }

  Future<void> _writeUnlocked(AdRewardOperation operation) {
    return _storage.write(
      key: storageKey,
      value: operation.encode(),
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
  }

  Future<void> delete() {
    return _mutationLock.synchronized(_deleteUnlocked);
  }

  Future<void> deleteIfCurrent({required int accountGeneration}) {
    return _mutationLock.synchronized(() {
      _requireCurrent(accountGeneration);
      return _deleteUnlocked();
    });
  }

  /// Synchronously invalidates every outstanding account lease, then drains
  /// any mutation already holding the lock and performs the final delete.
  /// Queued writes from the old account fail their lease check.
  Future<void> closeWritesAndClear() {
    _accountGeneration++;
    return _mutationLock.synchronized(_deleteUnlocked);
  }

  Future<void> _deleteUnlocked() {
    return _storage.delete(
      key: storageKey,
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
  }

  void _requireCurrent(int generation) {
    if (generation != _accountGeneration) {
      throw const StaleAdRewardAccountOperationException();
    }
  }
}

class AdRewardOperationSnapshot {
  const AdRewardOperationSnapshot({
    required this.operation,
    required this.accountGeneration,
  });

  final AdRewardOperation? operation;
  final int accountGeneration;
}

class AdRewardOperationReadException implements Exception {
  const AdRewardOperationReadException();
}

class StaleAdRewardAccountOperationException implements Exception {
  const StaleAdRewardAccountOperationException();
}

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

DateTime _requiredUtcInstant(Map<String, dynamic> json, String key) {
  final value = _optionalUtcInstant(json, key);
  if (value == null) {
    throw FormatException('Missing or invalid "$key".');
  }
  return value;
}

DateTime? _optionalUtcInstant(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid "$key".');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Invalid "$key".');
  }
  return parsed;
}
