import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_deletion_credentials.dart';
import '../repositories/account_deletion_credential_repository.dart';
import '../services/account_deletion_credential_service.dart';
import '../services/account_deletion_credential_store.dart';
import '../services/sensitive_clipboard_service.dart';
import 'api_provider.dart';

final accountDeletionCredentialServiceProvider =
    Provider<AccountDeletionCredentialService>((ref) {
      return AccountDeletionCredentialService(ref.watch(apiClientProvider));
    });

final accountDeletionCredentialStoreProvider =
    Provider<AccountDeletionCredentialStore>((ref) {
      return AccountDeletionCredentialStore();
    });

final accountDeletionCredentialRepositoryProvider =
    Provider<AccountDeletionCredentialRepository>((ref) {
      return DefaultAccountDeletionCredentialRepository(
        service: ref.watch(accountDeletionCredentialServiceProvider),
        store: ref.watch(accountDeletionCredentialStoreProvider),
      );
    });

final sensitiveClipboardServiceProvider =
    Provider.autoDispose<SensitiveClipboardService>((ref) {
      final service = SensitiveClipboardService();
      ref.onDispose(service.dispose);
      return service;
    });

final accountDeletionCredentialProvider =
    AsyncNotifierProvider.autoDispose<
      AccountDeletionCredentialController,
      AccountDeletionCredentialState
    >(AccountDeletionCredentialController.new);

class AccountDeletionCredentialController
    extends AsyncNotifier<AccountDeletionCredentialState> {
  AccountDeletionCredentialRepository get _repository =>
      ref.read(accountDeletionCredentialRepositoryProvider);

  @override
  Future<AccountDeletionCredentialState> build() {
    return _repository.load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<AccountDeletionCredentialState>();
    state = await AsyncValue.guard(_repository.load);
  }

  Future<bool> rotate() async {
    if (state.isLoading) {
      return false;
    }
    state = const AsyncLoading<AccountDeletionCredentialState>();
    final next = await AsyncValue.guard(_repository.rotate);
    state = next;
    return next.hasValue;
  }

  Future<bool> discardLocalCredential() async {
    if (state.isLoading) {
      return false;
    }
    state = const AsyncLoading<AccountDeletionCredentialState>();
    final next = await AsyncValue.guard(_repository.discardLocalCredential);
    state = next;
    return next.hasValue;
  }

  Future<String?> readRecoveryCode() async {
    final current = state.value;
    if (current == null) {
      return null;
    }
    return _repository.readRecoveryCode(current);
  }

  Future<bool> markBackupConfirmed() async {
    final current = state.value;
    if (current == null || state.isLoading) {
      return false;
    }
    final next = await AsyncValue.guard(
      () => _repository.markBackupConfirmed(current),
    );
    state = next;
    return next.hasValue;
  }
}
