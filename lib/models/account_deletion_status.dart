class AccountDeletionStatus {
  const AccountDeletionStatus({
    required this.completedAt,
    required this.expiresAt,
  });

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'completed') {
      throw const FormatException('Invalid account-deletion status.');
    }
    final completedAt = _requiredUtcInstant(json, 'completed_at');
    final expiresAt = _requiredUtcInstant(json, 'expires_at');
    if (!expiresAt.isAfter(completedAt)) {
      throw const FormatException(
        'Invalid account-deletion receipt timestamps.',
      );
    }
    return AccountDeletionStatus(
      completedAt: completedAt,
      expiresAt: expiresAt,
    );
  }

  final DateTime completedAt;
  final DateTime expiresAt;
}

DateTime _requiredUtcInstant(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Missing or invalid "$key".');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Missing or invalid "$key".');
  }
  return parsed;
}
