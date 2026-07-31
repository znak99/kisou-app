class OutlookQuota {
  const OutlookQuota({
    required this.date,
    required this.freeLimit,
    required this.freeUsed,
    required this.freeRemaining,
    required this.rewardCredits,
    required this.totalRemaining,
    required this.resetsAt,
    required this.adsAvailable,
  });

  factory OutlookQuota.fromJson(Map<String, dynamic> json) {
    final date = _requiredString(json, 'date');
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Invalid outlook quota date.');
    }

    final freeLimit = _nonNegativeInt(json, 'free_limit');
    final freeUsed = _nonNegativeInt(json, 'free_used');
    final freeRemaining = _nonNegativeInt(json, 'free_remaining');
    final rewardCredits = _nonNegativeInt(json, 'reward_credits');
    final totalRemaining = _nonNegativeInt(json, 'total_remaining');
    final resetsAt = DateTime.tryParse(_requiredString(json, 'resets_at'));
    final adsAvailable = json['ads_available'];
    if (resetsAt == null || !resetsAt.isUtc || adsAvailable is! bool) {
      throw const FormatException('Invalid outlook quota response.');
    }
    if (freeUsed > freeLimit ||
        freeRemaining != freeLimit - freeUsed ||
        totalRemaining != freeRemaining + rewardCredits) {
      throw const FormatException('Inconsistent outlook quota response.');
    }

    return OutlookQuota(
      date: date,
      freeLimit: freeLimit,
      freeUsed: freeUsed,
      freeRemaining: freeRemaining,
      rewardCredits: rewardCredits,
      totalRemaining: totalRemaining,
      resetsAt: resetsAt,
      adsAvailable: adsAvailable,
    );
  }

  static OutlookQuota screenshotFixture(String date) {
    return OutlookQuota(
      date: date,
      freeLimit: 3,
      freeUsed: 0,
      freeRemaining: 3,
      rewardCredits: 0,
      totalRemaining: 3,
      resetsAt: DateTime.utc(2100),
      adsAvailable: false,
    );
  }

  final String date;
  final int freeLimit;
  final int freeUsed;
  final int freeRemaining;
  final int rewardCredits;
  final int totalRemaining;
  final DateTime resetsAt;
  final bool adsAvailable;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid "$key".');
  }
  return value;
}

int _nonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('Missing or invalid "$key".');
  }
  return value;
}
