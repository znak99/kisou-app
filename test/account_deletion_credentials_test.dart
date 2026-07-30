import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/account_deletion_credentials.dart';
import 'package:kisou_app/providers/account_deletion_credential_provider.dart';
import 'package:kisou_app/repositories/account_deletion_credential_repository.dart';
import 'package:kisou_app/services/account_deletion_credential_service.dart';
import 'package:kisou_app/services/account_deletion_credential_store.dart';
import 'package:kisou_app/services/sensitive_clipboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _supportId = 'KSO-1234-5678-9ABC-DEFG-HJKM';
const _recoveryCode = '0123-4567-89AB-CDEF-GHJK-MNPQ-RSTV-WXYZ';
const _rotatedRecoveryCode = 'ZYXW-VTSR-QPNM-KJHG-FEDC-BA98-7654-3210';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('parses descriptor without exposing a plaintext code', () {
    final descriptor = AccountDeletionCredentialDescriptor.fromJson({
      'support_id': _supportId,
      'code_version': 3,
      'configured': true,
    });

    expect(descriptor.supportId, _supportId);
    expect(descriptor.codeVersion, 3);
    expect(descriptor.configured, isTrue);
  });

  test('rejects inconsistent descriptor and credential versions', () {
    expect(
      () => AccountDeletionCredentialDescriptor.fromJson({
        'support_id': null,
        'code_version': 1,
        'configured': false,
      }),
      throwsFormatException,
    );
    expect(
      () => AccountDeletionCredentialDescriptor.fromJson({
        'support_id': _supportId,
        'code_version': 0,
        'configured': true,
      }),
      throwsFormatException,
    );
    expect(
      () => IssuedAccountDeletionCredential.fromJson({
        'support_id': _supportId,
        'code_version': 0,
        'recovery_code': _recoveryCode,
      }),
      throwsFormatException,
    );
    expect(
      () => StoredAccountDeletionCredential.decode(
        '{"support_id":"$_supportId","code_version":0,'
        '"recovery_code":"$_recoveryCode"}',
      ),
      throwsFormatException,
    );
    expect(
      () => AccountDeletionCredentialDescriptor.fromJson({
        'support_id': 'KISOU-ABCD',
        'code_version': 1,
        'configured': true,
      }),
      throwsFormatException,
    );
    expect(
      () => IssuedAccountDeletionCredential.fromJson({
        'support_id': _supportId,
        'code_version': 1,
        'recovery_code': 'SECRET-CODE',
      }),
      throwsFormatException,
    );
  });

  test('redacts the plaintext code from diagnostic strings', () {
    const issued = IssuedAccountDeletionCredential(
      supportId: _supportId,
      codeVersion: 1,
      recoveryCode: _recoveryCode,
    );

    expect(issued.toString(), isNot(contains(_recoveryCode)));
    expect(
      issued.toStoredCredential().toString(),
      isNot(contains(_recoveryCode)),
    );
  });

  test('clipboard cleanup preserves content replaced by the user', () async {
    String? clipboard;
    final service = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async => clipboard = value,
      read: () async => clipboard,
    );

    await service.copy('SECRET-CODE');
    clipboard = 'user replacement';
    await service.clearIfUnchanged();
    expect(clipboard, 'user replacement');

    await service.copy('SECRET-CODE');
    await service.clearIfUnchanged();
    expect(clipboard, isEmpty);
  });

  test('ambiguous clipboard write failure is cleared immediately', () async {
    String? clipboard;
    var failNextSensitiveWrite = true;
    final service = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async {
        clipboard = value;
        if (value.isNotEmpty && failNextSensitiveWrite) {
          failNextSensitiveWrite = false;
          throw PlatformException(code: 'ambiguous-write');
        }
      },
      read: () async => clipboard,
    );

    await expectLater(
      service.copy(_recoveryCode),
      throwsA(isA<PlatformException>()),
    );
    expect(clipboard, isEmpty);
  });

  test('transient cleanup failure retains the fingerprint for retry', () async {
    String? clipboard;
    var failNextRead = true;
    final service = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async => clipboard = value,
      read: () async {
        if (failNextRead) {
          failNextRead = false;
          throw PlatformException(code: 'clipboard-busy');
        }
        return clipboard;
      },
    );

    await service.copy(_recoveryCode);
    await expectLater(
      service.clearIfUnchanged(),
      throwsA(isA<PlatformException>()),
    );
    expect(clipboard, _recoveryCode);

    await service.clearIfUnchanged();
    expect(clipboard, isEmpty);
  });

  test('an older cleanup cannot clear a newer sensitive copy', () async {
    String? clipboard;
    final delayedRead = Completer<String?>();
    final service = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async => clipboard = value,
      read: () => delayedRead.future,
    );

    await service.copy(_recoveryCode);
    final oldCleanup = service.clearIfUnchanged();
    await service.copy(_recoveryCode);
    delayedRead.complete(_recoveryCode);
    await oldCleanup;

    expect(clipboard, _recoveryCode);
    await service.clearIfUnchanged();
  });

  test('an in-flight cleanup cannot overwrite a newer copy', () async {
    String? clipboard;
    final emptyWriteStarted = Completer<void>();
    final allowEmptyWrite = Completer<void>();
    var delayNextEmptyWrite = true;
    final service = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async {
        if (value.isEmpty && delayNextEmptyWrite) {
          delayNextEmptyWrite = false;
          emptyWriteStarted.complete();
          await allowEmptyWrite.future;
        }
        clipboard = value;
      },
      read: () async => clipboard,
    );

    await service.copy(_recoveryCode);
    final oldCleanup = service.clearIfUnchanged();
    await emptyWriteStarted.future;
    final newerCopy = service.copy(_recoveryCode);
    allowEmptyWrite.complete();
    await Future.wait<void>([oldCleanup, newerCopy.then<void>((_) {})]);

    expect(clipboard, _recoveryCode);
    await service.clearIfUnchanged();
  });

  test('service uses the authenticated descriptor and rotate paths', () async {
    final requests = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add('${options.method} ${options.path}');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: options.method == 'GET'
                    ? {
                        'support_id': _supportId,
                        'code_version': 1,
                        'configured': true,
                      }
                    : {
                        'support_id': _supportId,
                        'code_version': 2,
                        'recovery_code': _rotatedRecoveryCode,
                      },
              ),
            );
          },
        ),
      );
    final service = AccountDeletionCredentialService(dio);

    final descriptor = await service.getDescriptor();
    final issued = await service.rotate();

    expect(descriptor.codeVersion, 1);
    expect(issued.codeVersion, 2);
    expect(requests, [
      'GET /users/me/account-deletion-credentials',
      'POST /users/me/account-deletion-credentials/rotate',
    ]);
  });

  test(
    'store keeps code encrypted and backup confirmation versioned',
    () async {
      const storage = FlutterSecureStorage();
      final store = AccountDeletionCredentialStore(storage: storage);
      const credential = StoredAccountDeletionCredential(
        supportId: _supportId,
        codeVersion: 4,
        recoveryCode: _recoveryCode,
      );

      await store.write(credential);
      expect((await store.read())?.recoveryCode, _recoveryCode);
      expect(
        await store.isBackupConfirmed(supportId: _supportId, codeVersion: 4),
        isFalse,
      );

      await store.markBackupConfirmed(supportId: _supportId, codeVersion: 4);
      expect(
        await store.isBackupConfirmed(supportId: _supportId, codeVersion: 4),
        isTrue,
      );
      expect(
        await store.isBackupConfirmed(supportId: _supportId, codeVersion: 5),
        isFalse,
      );
    },
  );

  test(
    'store preserves code after an ambiguous platform read failure',
    () async {
      final storage = _RecoverableReadFailureStorage();
      final store = AccountDeletionCredentialStore(storage: storage);

      await expectLater(
        store.read(),
        throwsA(isA<AccountDeletionCredentialReadException>()),
      );
      expect(storage.deletedCredential, isFalse);

      await store.delete();
      expect(storage.deletedCredential, isTrue);
    },
  );

  test('repository removes a local code with a stale server version', () async {
    final dio = _descriptorDio(
      supportId: _supportId,
      codeVersion: 2,
      configured: true,
    );
    final store = AccountDeletionCredentialStore();
    await store.write(
      const StoredAccountDeletionCredential(
        supportId: _supportId,
        codeVersion: 1,
        recoveryCode: _recoveryCode,
      ),
    );
    final repository = DefaultAccountDeletionCredentialRepository(
      service: AccountDeletionCredentialService(dio),
      store: store,
    );

    final state = await repository.load();

    expect(state.needsReplacement, isTrue);
    expect(await store.read(), isNull);
  });

  test('rotate persists the new code and resets backup confirmation', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'support_id': _supportId,
                  'code_version': 8,
                  'recovery_code': _rotatedRecoveryCode,
                },
              ),
            );
          },
        ),
      );
    final store = AccountDeletionCredentialStore();
    await store.markBackupConfirmed(supportId: _supportId, codeVersion: 7);
    final repository = DefaultAccountDeletionCredentialRepository(
      service: AccountDeletionCredentialService(dio),
      store: store,
    );

    final state = await repository.rotate();

    expect(state.hasLocalRecoveryCode, isTrue);
    expect(state.backupConfirmed, isFalse);
    expect(await repository.readRecoveryCode(state), _rotatedRecoveryCode);
  });

  test(
    'a stale read cannot delete a concurrently rotated credential',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'support_id': _supportId,
                    'code_version': 2,
                    'recovery_code': _rotatedRecoveryCode,
                  },
                ),
              );
            },
          ),
        );
      final store = _DelayedCredentialStore(
        const StoredAccountDeletionCredential(
          supportId: _supportId,
          codeVersion: 1,
          recoveryCode: _recoveryCode,
        ),
      );
      final repository = DefaultAccountDeletionCredentialRepository(
        service: AccountDeletionCredentialService(dio),
        store: store,
      );
      final oldState = AccountDeletionCredentialState(
        descriptor: const AccountDeletionCredentialDescriptor(
          supportId: _supportId,
          codeVersion: 1,
          configured: true,
        ),
        hasLocalRecoveryCode: true,
        backupConfirmed: false,
      );

      final staleRead = repository.readRecoveryCode(oldState);
      await store.readStarted.future;
      final rotatedState = await repository.rotate();
      store.allowRead.complete();

      expect(await staleRead, isNull);
      expect(rotatedState.descriptor.codeVersion, 2);
      expect(store.deleteCalls, 0);
      expect(store.current?.codeVersion, 2);
      expect(store.current?.recoveryCode, _rotatedRecoveryCode);
    },
  );

  test('provider never retains the plaintext code in state', () async {
    final repository = _FakeRepository();
    final container = ProviderContainer(
      overrides: [
        accountDeletionCredentialRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      accountDeletionCredentialProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final initial = await container.read(
      accountDeletionCredentialProvider.future,
    );
    expect(initial.hasLocalRecoveryCode, isFalse);

    expect(
      await container.read(accountDeletionCredentialProvider.notifier).rotate(),
      isTrue,
    );
    final state = container
        .read(accountDeletionCredentialProvider)
        .requireValue;
    expect(state.hasLocalRecoveryCode, isTrue);
    expect(state.toString(), isNot(contains(_recoveryCode)));
    expect(repository.rotateCalls, 1);
  });
}

Dio _descriptorDio({
  required String supportId,
  required int codeVersion,
  required bool configured,
}) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'support_id': supportId,
                'code_version': codeVersion,
                'configured': configured,
              },
            ),
          );
        },
      ),
    );
}

class _FakeRepository implements AccountDeletionCredentialRepository {
  var rotateCalls = 0;

  @override
  Future<AccountDeletionCredentialState> load() async {
    return AccountDeletionCredentialState(
      descriptor: const AccountDeletionCredentialDescriptor(
        supportId: null,
        codeVersion: 0,
        configured: false,
      ),
      hasLocalRecoveryCode: false,
      backupConfirmed: false,
    );
  }

  @override
  Future<AccountDeletionCredentialState> rotate() async {
    rotateCalls += 1;
    return AccountDeletionCredentialState(
      descriptor: const AccountDeletionCredentialDescriptor(
        supportId: _supportId,
        codeVersion: 1,
        configured: true,
      ),
      hasLocalRecoveryCode: true,
      backupConfirmed: false,
    );
  }

  @override
  Future<AccountDeletionCredentialState> discardLocalCredential() {
    return load();
  }

  @override
  Future<String?> readRecoveryCode(
    AccountDeletionCredentialState currentState,
  ) async {
    return currentState.hasLocalRecoveryCode ? _recoveryCode : null;
  }

  @override
  Future<AccountDeletionCredentialState> markBackupConfirmed(
    AccountDeletionCredentialState currentState,
  ) async {
    return AccountDeletionCredentialState(
      descriptor: currentState.descriptor,
      hasLocalRecoveryCode: currentState.hasLocalRecoveryCode,
      backupConfirmed: true,
    );
  }
}

class _RecoverableReadFailureStorage extends FlutterSecureStorage {
  var deletedCredential = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw PlatformException(code: 'invalidated-key');
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
    deletedCredential = true;
  }
}

class _DelayedCredentialStore extends AccountDeletionCredentialStore {
  _DelayedCredentialStore(this.current);

  StoredAccountDeletionCredential? current;
  final readStarted = Completer<void>();
  final allowRead = Completer<void>();
  var deleteCalls = 0;
  var _delayNextRead = true;

  @override
  Future<StoredAccountDeletionCredential?> read() async {
    if (_delayNextRead) {
      _delayNextRead = false;
      readStarted.complete();
      await allowRead.future;
    }
    return current;
  }

  @override
  Future<void> write(StoredAccountDeletionCredential credential) async {
    current = credential;
  }

  @override
  Future<void> delete() async {
    deleteCalls += 1;
    current = null;
  }

  @override
  Future<bool> isBackupConfirmed({
    required String supportId,
    required int codeVersion,
  }) async {
    return false;
  }

  @override
  Future<void> markBackupConfirmed({
    required String supportId,
    required int codeVersion,
  }) async {}
}
