import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/account_deletion_credentials.dart';

/// Stores only the plaintext deletion code in encrypted, device-bound storage.
///
/// Backup confirmation is non-sensitive metadata and is kept separately in
/// SharedPreferences. It is versioned so replacement always requires a fresh
/// confirmation.
class AccountDeletionCredentialStore {
  AccountDeletionCredentialStore({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  static const _credentialKey = 'account_deletion_credential_v1';
  static const _backupConfirmationKey =
      'account_deletion_credential_backup_confirmation_v1';
  static final _iOptions = IOSOptions(
    accountName: ApiConfig.secureStorageService,
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );
  static const _aOptions = AndroidOptions(resetOnError: false);

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _preferencesFactory;

  Future<StoredAccountDeletionCredential?> read() async {
    try {
      final encoded = await _storage.read(
        key: _credentialKey,
        iOptions: _iOptions,
        aOptions: _aOptions,
      );
      if (encoded == null || encoded.isEmpty) {
        return null;
      }
      return StoredAccountDeletionCredential.decode(encoded);
    } on FormatException {
      await delete();
      return null;
    } on PlatformException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AccountDeletionCredentialReadException(),
        stackTrace,
      );
    }
  }

  Future<void> write(StoredAccountDeletionCredential credential) {
    return _storage.write(
      key: _credentialKey,
      value: credential.encode(),
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
  }

  Future<void> delete() async {
    await _storage.delete(
      key: _credentialKey,
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
    final preferences = await _preferencesFactory();
    await preferences.remove(_backupConfirmationKey);
  }

  Future<bool> isBackupConfirmed({
    required String supportId,
    required int codeVersion,
  }) async {
    final preferences = await _preferencesFactory();
    return preferences.getString(_backupConfirmationKey) ==
        _backupConfirmationValue(
          supportId: supportId,
          codeVersion: codeVersion,
        );
  }

  Future<void> markBackupConfirmed({
    required String supportId,
    required int codeVersion,
  }) async {
    final preferences = await _preferencesFactory();
    await preferences.setString(
      _backupConfirmationKey,
      _backupConfirmationValue(supportId: supportId, codeVersion: codeVersion),
    );
  }

  String _backupConfirmationValue({
    required String supportId,
    required int codeVersion,
  }) {
    return '$supportId:$codeVersion';
  }
}

class AccountDeletionCredentialReadException implements Exception {
  const AccountDeletionCredentialReadException();

  @override
  String toString() => 'The local account-deletion credential is unavailable.';
}
