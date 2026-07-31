import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/ad_config.dart';
import 'package:kisou_app/services/ad_reward_operation_store.dart';

void main() {
  test('round-trips stages without persisting raw SSV challenge text', () {
    final issuing = _issuing();
    final presented = issuing
        .withIssuedChallenge(
          challengeId: '123e4567-e89b-42d3-a456-426614174000',
          expiresAt: DateTime.utc(2026, 7, 31, 0, 15),
          settlementExpiresAt: DateTime.utc(2026, 8, 1, 0, 15),
        )
        .asPresented();

    final encoded = presented.encode();
    final decoded = AdRewardOperation.decode(encoded);

    expect(encoded, isNot(contains(List.filled(43, 'A').join())));
    expect(decoded.stage, AdRewardOperationStage.presented);
    expect(decoded.idempotencyKey, issuing.idempotencyKey);
    expect(decoded.challengeId, presented.challengeId);
  });

  test('rejects partial challenge fields and non-canonical UUIDs', () {
    expect(
      () => AdRewardOperation.decode(
        '{"version":1,'
        '"idempotency_key":"11111111-1111-4111-8111-111111111111",'
        '"platform":"android",'
        '"ad_unit_id":"unit",'
        '"stage":"issuing",'
        '"created_at":"2026-07-31T00:00:00.000Z",'
        '"challenge_id":"123e4567-e89b-42d3-a456-426614174000"}',
      ),
      throwsFormatException,
    );
    expect(
      () => AdRewardOperation.decode(
        '{"version":1,'
        '"idempotency_key":"AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",'
        '"platform":"android",'
        '"ad_unit_id":"unit",'
        '"stage":"issuing",'
        '"created_at":"2026-07-31T00:00:00.000Z"}',
      ),
      throwsFormatException,
    );
  });

  test(
    'account close drains an active write, deletes it, and rejects queued old writes',
    () async {
      final storage = _DelayedWriteStorage();
      final store = AdRewardOperationStore(storage: storage);
      final snapshot = await store.readSnapshot();
      final firstWrite = store.writeIfCurrent(
        _issuing(),
        accountGeneration: snapshot.accountGeneration,
      );
      await storage.writeStarted.future;

      final closing = store.closeWritesAndClear();
      final queuedOldWriteExpectation = expectLater(
        store.writeIfCurrent(
          _issuing(idempotencyKey: '22222222-2222-4222-8222-222222222222'),
          accountGeneration: snapshot.accountGeneration,
        ),
        throwsA(isA<StaleAdRewardAccountOperationException>()),
      );
      storage.allowWrite.complete();

      await firstWrite;
      await closing;
      await queuedOldWriteExpectation;
      expect(await store.read(), isNull);
      expect(storage.deleteCalls, 1);
    },
  );

  test('corrupt storage remains fail-closed instead of being erased', () async {
    final storage = _DelayedWriteStorage(value: '{corrupt');
    final store = AdRewardOperationStore(storage: storage);

    await expectLater(
      store.read(),
      throwsA(isA<AdRewardOperationReadException>()),
    );

    expect(storage.value, '{corrupt');
    expect(storage.deleteCalls, 0);
  });
}

AdRewardOperation _issuing({
  String idempotencyKey = '11111111-1111-4111-8111-111111111111',
}) {
  return AdRewardOperation.issuing(
    idempotencyKey: idempotencyKey,
    platform: KisouAdPlatform.android,
    adUnitId: AdConfig.androidSamples.rewardedId,
    createdAt: DateTime.utc(2026, 7, 31),
  );
}

class _DelayedWriteStorage extends FlutterSecureStorage {
  _DelayedWriteStorage({this.value});

  String? value;
  final writeStarted = Completer<void>();
  final allowWrite = Completer<void>();
  var deleteCalls = 0;

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
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    await allowWrite.future;
    this.value = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleteCalls++;
    value = null;
  }
}
