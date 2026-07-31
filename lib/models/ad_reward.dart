import '../config/ad_config.dart';

enum AdRewardChallengeState {
  pending,
  settling,
  credited,
  consumed,
  expired;

  static AdRewardChallengeState parse(Object? value) {
    return switch (value) {
      'pending' => pending,
      'settling' => settling,
      'credited' => credited,
      'consumed' => consumed,
      'expired' => expired,
      _ => throw const FormatException('Invalid reward challenge status.'),
    };
  }
}

class AdRewardChallengeStatus {
  const AdRewardChallengeStatus({
    required this.id,
    required this.platform,
    required this.status,
    required this.expiresAt,
    required this.settlementExpiresAt,
    required this.creditedAt,
    required this.consumedAt,
  });

  factory AdRewardChallengeStatus.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    if (!_uuidPattern.hasMatch(id)) {
      throw const FormatException('Invalid reward challenge ID.');
    }
    final platform = switch (json['platform']) {
      'android' => KisouAdPlatform.android,
      'ios' => KisouAdPlatform.ios,
      _ => throw const FormatException('Invalid reward challenge platform.'),
    };
    final status = AdRewardChallengeState.parse(json['status']);
    final expiresAt = _requiredUtcInstant(json, 'expires_at');
    final settlementExpiresAt = _requiredUtcInstant(
      json,
      'settlement_expires_at',
    );
    final creditedAt = _optionalUtcInstant(json, 'credited_at');
    final consumedAt = _optionalUtcInstant(json, 'consumed_at');
    if (!settlementExpiresAt.isAfter(expiresAt) ||
        creditedAt != null && creditedAt.isAfter(settlementExpiresAt) ||
        creditedAt != null &&
            consumedAt != null &&
            consumedAt.isBefore(creditedAt)) {
      throw const FormatException('Inconsistent reward challenge timestamps.');
    }
    final timestampsMatchStatus = switch (status) {
      AdRewardChallengeState.pending ||
      AdRewardChallengeState.settling ||
      AdRewardChallengeState.expired =>
        creditedAt == null && consumedAt == null,
      AdRewardChallengeState.credited =>
        creditedAt != null && consumedAt == null,
      AdRewardChallengeState.consumed =>
        creditedAt != null && consumedAt != null,
    };
    if (!timestampsMatchStatus) {
      throw const FormatException(
        'Reward challenge status does not match its timestamps.',
      );
    }
    return AdRewardChallengeStatus(
      id: id,
      platform: platform,
      status: status,
      expiresAt: expiresAt,
      settlementExpiresAt: settlementExpiresAt,
      creditedAt: creditedAt,
      consumedAt: consumedAt,
    );
  }

  final String id;
  final KisouAdPlatform platform;
  final AdRewardChallengeState status;
  final DateTime expiresAt;
  final DateTime settlementExpiresAt;
  final DateTime? creditedAt;
  final DateTime? consumedAt;
}

class AdRewardChallenge extends AdRewardChallengeStatus {
  const AdRewardChallenge({
    required super.id,
    required super.platform,
    required super.status,
    required super.expiresAt,
    required super.settlementExpiresAt,
    required super.creditedAt,
    required super.consumedAt,
    required this.challenge,
  });

  factory AdRewardChallenge.fromJson(Map<String, dynamic> json) {
    final status = AdRewardChallengeStatus.fromJson(json);
    final challenge = _requiredString(json, 'challenge');
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(challenge)) {
      throw const FormatException('Invalid reward challenge payload.');
    }
    return AdRewardChallenge(
      id: status.id,
      platform: status.platform,
      status: status.status,
      expiresAt: status.expiresAt,
      settlementExpiresAt: status.settlementExpiresAt,
      creditedAt: status.creditedAt,
      consumedAt: status.consumedAt,
      challenge: challenge,
    );
  }

  final String challenge;
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
  r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid "$key".');
  }
  return value;
}

DateTime _requiredUtcInstant(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(_requiredString(json, key));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Missing or invalid "$key".');
  }
  return parsed;
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
