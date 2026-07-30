import 'dart:convert';

final _supportIdPattern = RegExp(
  r'^KSO-(?:[0-9A-HJKM-NP-TV-Z]{4}-){4}[0-9A-HJKM-NP-TV-Z]{4}$',
);
final _recoveryCodePattern = RegExp(
  r'^(?:[0-9A-HJKM-NP-TV-Z]{4}-){7}[0-9A-HJKM-NP-TV-Z]{4}$',
);

/// Server-side account deletion credential metadata.
///
/// The recovery code is deliberately absent from this descriptor because the
/// server only returns the original value when it is issued or replaced.
class AccountDeletionCredentialDescriptor {
  const AccountDeletionCredentialDescriptor({
    required this.supportId,
    required this.codeVersion,
    required this.configured,
  });

  factory AccountDeletionCredentialDescriptor.fromJson(
    Map<String, dynamic> json,
  ) {
    final supportId = (json['support_id'] as String?)?.trim();
    final codeVersion = json['code_version'];
    final configured = json['configured'];
    if (codeVersion is! int || configured is! bool) {
      throw const FormatException(
        'Account deletion credential descriptor is invalid.',
      );
    }
    if (configured &&
        (supportId == null || !_supportIdPattern.hasMatch(supportId))) {
      throw const FormatException(
        'Configured account deletion credentials require a valid support ID.',
      );
    }
    if ((configured && codeVersion < 1) ||
        (!configured &&
            (codeVersion != 0 ||
                (supportId != null && supportId.isNotEmpty)))) {
      throw const FormatException(
        'Account deletion credential state is inconsistent.',
      );
    }
    return AccountDeletionCredentialDescriptor(
      supportId: supportId == null || supportId.isEmpty ? null : supportId,
      codeVersion: codeVersion,
      configured: configured,
    );
  }

  final String? supportId;
  final int codeVersion;
  final bool configured;
}

/// The one-time plaintext returned after issuing or replacing the code.
class IssuedAccountDeletionCredential {
  const IssuedAccountDeletionCredential({
    required this.supportId,
    required this.codeVersion,
    required this.recoveryCode,
  });

  factory IssuedAccountDeletionCredential.fromJson(Map<String, dynamic> json) {
    final supportId = (json['support_id'] as String?)?.trim();
    final codeVersion = json['code_version'];
    final recoveryCode = (json['recovery_code'] as String?)?.trim();
    if (supportId == null ||
        !_supportIdPattern.hasMatch(supportId) ||
        codeVersion is! int ||
        codeVersion < 1 ||
        recoveryCode == null ||
        !_recoveryCodePattern.hasMatch(recoveryCode)) {
      throw const FormatException(
        'Issued account deletion credential is invalid.',
      );
    }
    return IssuedAccountDeletionCredential(
      supportId: supportId,
      codeVersion: codeVersion,
      recoveryCode: recoveryCode,
    );
  }

  final String supportId;
  final int codeVersion;
  final String recoveryCode;

  StoredAccountDeletionCredential toStoredCredential() {
    return StoredAccountDeletionCredential(
      supportId: supportId,
      codeVersion: codeVersion,
      recoveryCode: recoveryCode,
    );
  }

  @override
  String toString() {
    return 'IssuedAccountDeletionCredential('
        'supportId: $supportId, codeVersion: $codeVersion, '
        'recoveryCode: <redacted>)';
  }
}

/// Device-local encrypted representation of the deletion credential.
class StoredAccountDeletionCredential {
  const StoredAccountDeletionCredential({
    required this.supportId,
    required this.codeVersion,
    required this.recoveryCode,
  });

  factory StoredAccountDeletionCredential.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Stored account deletion credential is invalid.',
      );
    }
    final rawSupportId = decoded['support_id'];
    final codeVersion = decoded['code_version'];
    final rawRecoveryCode = decoded['recovery_code'];
    final supportId = rawSupportId is String ? rawSupportId.trim() : null;
    final recoveryCode = rawRecoveryCode is String
        ? rawRecoveryCode.trim()
        : null;
    if (supportId == null ||
        !_supportIdPattern.hasMatch(supportId) ||
        codeVersion is! int ||
        codeVersion < 1 ||
        recoveryCode == null ||
        !_recoveryCodePattern.hasMatch(recoveryCode)) {
      throw const FormatException(
        'Stored account deletion credential is invalid.',
      );
    }
    return StoredAccountDeletionCredential(
      supportId: supportId,
      codeVersion: codeVersion,
      recoveryCode: recoveryCode,
    );
  }

  final String supportId;
  final int codeVersion;
  final String recoveryCode;

  String encode() {
    return jsonEncode({
      'support_id': supportId,
      'code_version': codeVersion,
      'recovery_code': recoveryCode,
    });
  }

  bool matches(AccountDeletionCredentialDescriptor descriptor) {
    return descriptor.configured &&
        descriptor.supportId == supportId &&
        descriptor.codeVersion == codeVersion;
  }

  @override
  String toString() {
    return 'StoredAccountDeletionCredential('
        'supportId: $supportId, codeVersion: $codeVersion, '
        'recoveryCode: <redacted>)';
  }
}

/// Non-sensitive state safe to retain in Riverpod.
class AccountDeletionCredentialState {
  const AccountDeletionCredentialState({
    required this.descriptor,
    required this.hasLocalRecoveryCode,
    required this.backupConfirmed,
  });

  final AccountDeletionCredentialDescriptor descriptor;
  final bool hasLocalRecoveryCode;
  final bool backupConfirmed;

  bool get needsIssue => !descriptor.configured;
  bool get needsReplacement => descriptor.configured && !hasLocalRecoveryCode;
}
