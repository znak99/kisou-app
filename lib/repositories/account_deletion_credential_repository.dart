import '../models/account_deletion_credentials.dart';
import '../services/account_deletion_credential_service.dart';
import '../services/account_deletion_credential_store.dart';

abstract interface class AccountDeletionCredentialRepository {
  Future<AccountDeletionCredentialState> load();

  Future<AccountDeletionCredentialState> rotate();

  Future<AccountDeletionCredentialState> discardLocalCredential();

  Future<String?> readRecoveryCode(AccountDeletionCredentialState currentState);

  Future<AccountDeletionCredentialState> markBackupConfirmed(
    AccountDeletionCredentialState currentState,
  );
}

class DefaultAccountDeletionCredentialRepository
    implements AccountDeletionCredentialRepository {
  const DefaultAccountDeletionCredentialRepository({
    required AccountDeletionCredentialService service,
    required AccountDeletionCredentialStore store,
  }) : _service = service,
       _store = store;

  final AccountDeletionCredentialService _service;
  final AccountDeletionCredentialStore _store;

  @override
  Future<AccountDeletionCredentialState> load() async {
    final descriptor = await _service.getDescriptor();
    var stored = await _store.read();
    if (stored != null && !stored.matches(descriptor)) {
      await _store.delete();
      stored = null;
    }
    if (!descriptor.configured && stored != null) {
      await _store.delete();
      stored = null;
    }
    return _stateFrom(descriptor: descriptor, stored: stored);
  }

  @override
  Future<AccountDeletionCredentialState> rotate() async {
    final issued = await _service.rotate();
    final stored = issued.toStoredCredential();
    await _store.write(stored);
    return _stateFrom(
      descriptor: AccountDeletionCredentialDescriptor(
        supportId: issued.supportId,
        codeVersion: issued.codeVersion,
        configured: true,
      ),
      stored: stored,
    );
  }

  @override
  Future<AccountDeletionCredentialState> discardLocalCredential() async {
    await _store.delete();
    return load();
  }

  @override
  Future<String?> readRecoveryCode(
    AccountDeletionCredentialState currentState,
  ) async {
    final stored = await _store.read();
    if (stored == null || !stored.matches(currentState.descriptor)) {
      return null;
    }
    return stored.recoveryCode;
  }

  @override
  Future<AccountDeletionCredentialState> markBackupConfirmed(
    AccountDeletionCredentialState currentState,
  ) async {
    final supportId = currentState.descriptor.supportId;
    if (supportId == null || !currentState.hasLocalRecoveryCode) {
      throw StateError('There is no local recovery code to confirm.');
    }
    await _store.markBackupConfirmed(
      supportId: supportId,
      codeVersion: currentState.descriptor.codeVersion,
    );
    return AccountDeletionCredentialState(
      descriptor: currentState.descriptor,
      hasLocalRecoveryCode: true,
      backupConfirmed: true,
    );
  }

  Future<AccountDeletionCredentialState> _stateFrom({
    required AccountDeletionCredentialDescriptor descriptor,
    required StoredAccountDeletionCredential? stored,
  }) async {
    final matches = stored?.matches(descriptor) ?? false;
    final supportId = descriptor.supportId;
    final backupConfirmed = matches && supportId != null
        ? await _store.isBackupConfirmed(
            supportId: supportId,
            codeVersion: descriptor.codeVersion,
          )
        : false;
    return AccountDeletionCredentialState(
      descriptor: descriptor,
      hasLocalRecoveryCode: matches,
      backupConfirmed: backupConfirmed,
    );
  }
}
