import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/outlook_quota.dart';

void main() {
  test('parses the authoritative quota contract', () {
    final quota = OutlookQuota.fromJson(_validQuota());

    expect(quota.date, '2026-07-31');
    expect(quota.freeLimit, 3);
    expect(quota.freeUsed, 2);
    expect(quota.freeRemaining, 1);
    expect(quota.rewardCredits, 2);
    expect(quota.totalRemaining, 3);
    expect(quota.resetsAt, DateTime.utc(2026, 7, 31, 15));
    expect(quota.adsAvailable, isTrue);
  });

  test('rejects negative, inconsistent, or non-UTC quota data', () {
    final invalidPayloads = [
      {..._validQuota(), 'free_used': -1},
      {..._validQuota(), 'free_remaining': 2},
      {..._validQuota(), 'total_remaining': 99},
      {..._validQuota(), 'resets_at': '2026-08-01T00:00:00'},
      {..._validQuota(), 'ads_available': 'true'},
    ];

    for (final payload in invalidPayloads) {
      expect(() => OutlookQuota.fromJson(payload), throwsFormatException);
    }
  });
}

Map<String, dynamic> _validQuota() {
  return {
    'date': '2026-07-31',
    'free_limit': 3,
    'free_used': 2,
    'free_remaining': 1,
    'reward_credits': 2,
    'total_remaining': 3,
    'resets_at': '2026-07-31T15:00:00Z',
    'ads_available': true,
  };
}
