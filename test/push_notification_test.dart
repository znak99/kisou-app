import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/push_notification.dart';

void main() {
  const deliveryId = '123e4567-e89b-42d3-a456-426614174000';

  test('accepts only the minimal versioned notification payload', () {
    final morning = PushNotificationIntent.fromData(const {
      'schema_version': '1',
      'type': 'morning_recommendation',
      'delivery_id': deliveryId,
      'client_revision': '1',
    });
    final evening = PushNotificationIntent.fromData(const {
      'schema_version': '1',
      'type': 'evening_feedback',
      'delivery_id': deliveryId,
      'client_revision': '9223372036854775807',
    });

    expect(morning.type, PushNotificationType.morningRecommendation);
    expect(morning.clientRevision, 1);
    expect(evening.type, PushNotificationType.eveningFeedback);

    for (final invalid in [
      const {
        'schema_version': '2',
        'type': 'morning_recommendation',
        'delivery_id': deliveryId,
        'client_revision': '1',
      },
      const {
        'schema_version': '1',
        'type': 'unknown',
        'delivery_id': deliveryId,
        'client_revision': '1',
      },
      const {
        'schema_version': '1',
        'type': 'morning_recommendation',
        'delivery_id': 'not-a-uuid',
        'client_revision': '1',
      },
      const {
        'schema_version': '1',
        'type': 'morning_recommendation',
        'delivery_id': deliveryId,
        'client_revision': '1',
        'user_id': 'must-not-be-present',
      },
      const {
        'schema_version': '1',
        'type': 'morning_recommendation',
        'delivery_id': deliveryId,
        'client_revision': '0',
      },
      const {
        'schema_version': '1',
        'type': 'morning_recommendation',
        'delivery_id': deliveryId,
        'client_revision': '01',
      },
      const {
        'schema_version': '1',
        'type': 'morning_recommendation',
        'delivery_id': deliveryId,
        'client_revision': '9223372036854775808',
      },
    ]) {
      expect(
        () => PushNotificationIntent.fromData(invalid),
        throwsFormatException,
      );
    }
  });

  test('preferences round-trip with fixed JST timezone and strict times', () {
    const preferences = PushPreferences(
      morningEnabled: true,
      morningTime: NotificationTime(hour: 6, minute: 5),
      eveningEnabled: true,
      eveningTime: NotificationTime(hour: 21, minute: 45),
    );

    expect(PushPreferences.fromJson(preferences.toJson()), preferences);
    expect(preferences.toJson()['timezone'], 'Asia/Tokyo');
    expect(preferences.morningTime.apiValue, '06:05');
    expect(parseNotificationTime('23:59').apiValue, '23:59');
    expect(() => parseNotificationTime('24:00'), throwsFormatException);
    expect(() => parseNotificationTime('7:00'), throwsFormatException);
  });

  test('preferences reject missing, extra, or alternate-timezone fields', () {
    final base = PushPreferences.defaults.toJson();
    expect(
      () => PushPreferences.fromJson({...base, 'latitude': 35.0}),
      throwsFormatException,
    );
    final missing = Map<String, dynamic>.from(base)..remove('morning_time');
    expect(() => PushPreferences.fromJson(missing), throwsFormatException);
    expect(
      () => PushPreferences.fromJson({...base, 'timezone': 'UTC'}),
      throwsFormatException,
    );
  });
}
