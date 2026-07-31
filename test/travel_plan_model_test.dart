import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/services/travel_notification_service.dart';

void main() {
  group('TravelPlan JST date handling', () {
    test('converts a JST civil departure to its UTC instant', () {
      final utc = jstCivilDateTimeToUtc(
        date: DateTime(2026, 8, 10),
        hour: 7,
        minute: 30,
      );

      expect(utc, DateTime.utc(2026, 8, 9, 22, 30));
      expect(utc.isUtc, isTrue);
    });

    test('calculates D-day from JST dates outside the device timezone', () {
      final plan = _plan(departureAtUtc: DateTime.utc(2026, 8, 2, 0));

      expect(plan.dDayAt(DateTime.utc(2026, 7, 31, 14, 59)), 2);
      expect(plan.dDayAt(DateTime.utc(2026, 7, 31, 15)), 1);
      expect(plan.dDayAt(DateTime.utc(2026, 8, 1, 15)), 0);
      expect(plan.dDayAt(DateTime.utc(2026, 8, 2, 15)), -1);
    });

    test('derives reminder instants without changing the departure time', () {
      final departure = DateTime.utc(2026, 8, 2, 0);

      expect(
        _plan(
          departureAtUtc: departure,
          reminder: TravelReminder.dayBefore,
        ).reminderAtUtc,
        DateTime.utc(2026, 8, 1, 0),
      );
      expect(
        _plan(
          departureAtUtc: departure,
          reminder: TravelReminder.threeHoursBefore,
        ).reminderAtUtc,
        DateTime.utc(2026, 8, 1, 21),
      );
    });

    test('new-plan default advances to the next JST whole hour', () {
      expect(
        nextTravelDepartureOnJstClock(DateTime.utc(2026, 8, 1, 3, 25)),
        DateTime(2026, 8, 1, 13),
      );
      expect(
        nextTravelDepartureOnJstClock(DateTime.utc(2026, 8, 1, 14, 45)),
        DateTime(2026, 8, 2),
      );
    });
  });

  group('Travel notification payload', () {
    test('accepts only the travel namespace and a positive plan id', () {
      expect(parseTravelNotificationPayload('travel:42'), 42);
      expect(parseTravelNotificationPayload('forecast:42'), isNull);
      expect(parseTravelNotificationPayload('travel:0'), isNull);
      expect(parseTravelNotificationPayload('travel:1:extra'), isNull);
      expect(parseTravelNotificationPayload(null), isNull);
    });
  });

  test('rejects an opted-in reminder whose trigger instant has passed', () {
    final now = DateTime.utc(2026, 8, 1, 12);
    final draft = TravelPlanDraft(
      cityCode: 'tokyo',
      departureAtUtc: now.add(const Duration(hours: 2)),
      reminder: TravelReminder.threeHoursBefore,
    );

    expect(
      () => draft.validate(nowUtc: now),
      throwsA(
        isA<TravelPlanValidationException>().having(
          (error) => error.code,
          'code',
          'reminder_not_future',
        ),
      ),
    );
  });
}

TravelPlan _plan({
  required DateTime departureAtUtc,
  TravelReminder reminder = TravelReminder.none,
}) {
  return TravelPlan(
    id: 1,
    cityCode: 'tokyo',
    departureAtUtc: departureAtUtc,
    reminder: reminder,
    notificationId: travelNotificationIdMin + 1,
    syncState: reminder == TravelReminder.none
        ? TravelNotificationSyncState.none
        : TravelNotificationSyncState.pendingSchedule,
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
  );
}
