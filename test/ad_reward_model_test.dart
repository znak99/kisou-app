import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/ad_reward.dart';

void main() {
  test('parses the exact challenge and settlement contract', () {
    final challenge = AdRewardChallenge.fromJson({
      ..._pendingStatus(),
      'challenge': _repeat('A', 43),
    });

    expect(challenge.challenge, _repeat('A', 43));
    expect(challenge.status, AdRewardChallengeState.pending);
    expect(challenge.settlementExpiresAt, DateTime.utc(2026, 8, 1, 1));
  });

  test('rejects challenge text outside URL-safe 43 characters', () {
    for (final value in [
      _repeat('A', 42),
      _repeat('A', 44),
      '${_repeat('A', 42)}+',
      _repeat('한', 43),
    ]) {
      expect(
        () => AdRewardChallenge.fromJson({
          ..._pendingStatus(),
          'challenge': value,
        }),
        throwsFormatException,
      );
    }
  });

  test('rejects settlement windows that do not follow expiry', () {
    expect(
      () => AdRewardChallengeStatus.fromJson({
        ..._pendingStatus(),
        'settlement_expires_at': '2026-08-01T00:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('rejects status and timestamp drift', () {
    final invalid = [
      {..._pendingStatus(), 'status': 'credited'},
      {
        ..._pendingStatus(),
        'status': 'pending',
        'credited_at': '2026-08-01T00:30:00Z',
      },
      {
        ..._pendingStatus(),
        'status': 'consumed',
        'credited_at': '2026-08-01T00:30:00Z',
      },
      {
        ..._pendingStatus(),
        'status': 'consumed',
        'credited_at': '2026-08-01T00:40:00Z',
        'consumed_at': '2026-08-01T00:30:00Z',
      },
      {
        ..._pendingStatus(),
        'status': 'credited',
        'credited_at': '2026-08-01T01:00:01Z',
      },
    ];

    for (final payload in invalid) {
      expect(
        () => AdRewardChallengeStatus.fromJson(payload),
        throwsFormatException,
      );
    }
  });

  test('accepts credited and consumed timestamp combinations', () {
    final credited = AdRewardChallengeStatus.fromJson({
      ..._pendingStatus(),
      'status': 'credited',
      'credited_at': '2026-08-01T00:30:00Z',
    });
    final consumed = AdRewardChallengeStatus.fromJson({
      ..._pendingStatus(),
      'status': 'consumed',
      'credited_at': '2026-08-01T00:30:00Z',
      'consumed_at': '2026-08-02T00:00:00Z',
    });

    expect(credited.status, AdRewardChallengeState.credited);
    expect(consumed.status, AdRewardChallengeState.consumed);
  });
}

String _repeat(String value, int count) => List.filled(count, value).join();

Map<String, dynamic> _pendingStatus() {
  return {
    'id': '123e4567-e89b-42d3-a456-426614174000',
    'platform': 'android',
    'status': 'pending',
    'expires_at': '2026-08-01T00:00:00Z',
    'settlement_expires_at': '2026-08-01T01:00:00Z',
    'credited_at': null,
    'consumed_at': null,
  };
}
