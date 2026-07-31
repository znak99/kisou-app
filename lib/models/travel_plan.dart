import '../constants/major_cities.dart';
import '../utils/jp_date.dart';

const travelNotificationIdMin = 100000;
const travelNotificationIdMax = 199999;
const maxTravelPlans = 20;

enum TravelReminder {
  none(0),
  dayBefore(24 * 60),
  threeHoursBefore(3 * 60);

  const TravelReminder(this.minutes);

  final int minutes;

  static TravelReminder fromMinutes(int value) {
    return TravelReminder.values.firstWhere(
      (item) => item.minutes == value,
      orElse: () =>
          throw FormatException('Unsupported travel reminder value: $value'),
    );
  }
}

enum TravelNotificationSyncState {
  none,
  pendingSchedule,
  scheduled,
  blockedPermission,
  pendingDelete;

  static TravelNotificationSyncState fromStorage(String value) {
    return TravelNotificationSyncState.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw FormatException(
        'Unsupported travel notification state: $value',
      ),
    );
  }
}

class TravelPlanDraft {
  const TravelPlanDraft({
    required this.cityCode,
    required this.departureAtUtc,
    required this.reminder,
  });

  final String cityCode;
  final DateTime departureAtUtc;
  final TravelReminder reminder;

  void validate({required DateTime nowUtc}) {
    if (majorCityByCode(cityCode) == null) {
      throw const TravelPlanValidationException('unknown_city');
    }
    if (!departureAtUtc.isUtc || !departureAtUtc.isAfter(nowUtc.toUtc())) {
      throw const TravelPlanValidationException('departure_not_future');
    }
    final reminderAtUtc = reminder == TravelReminder.none
        ? null
        : departureAtUtc.subtract(Duration(minutes: reminder.minutes));
    if (reminderAtUtc != null && !reminderAtUtc.isAfter(nowUtc.toUtc())) {
      throw const TravelPlanValidationException('reminder_not_future');
    }
  }
}

class TravelPlan {
  const TravelPlan({
    required this.id,
    required this.cityCode,
    required this.departureAtUtc,
    required this.reminder,
    required this.notificationId,
    required this.syncState,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory TravelPlan.fromStorage(Map<String, Object?> row) {
    final id = row['id'] as int;
    final notificationId = row['notification_id'] as int;
    final departureAtUtc = DateTime.fromMillisecondsSinceEpoch(
      row['departure_at_utc_ms'] as int,
      isUtc: true,
    );
    final createdAtUtc = DateTime.fromMillisecondsSinceEpoch(
      row['created_at_utc_ms'] as int,
      isUtc: true,
    );
    final updatedAtUtc = DateTime.fromMillisecondsSinceEpoch(
      row['updated_at_utc_ms'] as int,
      isUtc: true,
    );
    if (notificationId < travelNotificationIdMin ||
        notificationId > travelNotificationIdMax) {
      throw const FormatException('Travel notification id is out of range.');
    }
    final cityCode = row['destination_code'] as String;
    if (majorCityByCode(cityCode) == null) {
      throw const FormatException('Travel destination code is unknown.');
    }
    return TravelPlan(
      id: id,
      cityCode: cityCode,
      departureAtUtc: departureAtUtc,
      reminder: TravelReminder.fromMinutes(row['reminder_minutes'] as int),
      notificationId: notificationId,
      syncState: TravelNotificationSyncState.fromStorage(
        row['sync_state'] as String,
      ),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
    );
  }

  final int id;
  final String cityCode;
  final DateTime departureAtUtc;
  final TravelReminder reminder;
  final int notificationId;
  final TravelNotificationSyncState syncState;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  DateTime get departureOnJstClock =>
      departureAtUtc.toUtc().add(const Duration(hours: 9));

  DateTime? get reminderAtUtc => reminder == TravelReminder.none
      ? null
      : departureAtUtc.subtract(Duration(minutes: reminder.minutes));

  int dDayAt(DateTime instant) {
    final today = jstDateAt(instant);
    final departure = departureOnJstClock;
    return DateTime.utc(
      departure.year,
      departure.month,
      departure.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }

  bool isExpiredAt(DateTime instant) => dDayAt(instant) < 0;

  TravelPlan copyWith({
    String? cityCode,
    DateTime? departureAtUtc,
    TravelReminder? reminder,
    TravelNotificationSyncState? syncState,
    DateTime? updatedAtUtc,
  }) {
    return TravelPlan(
      id: id,
      cityCode: cityCode ?? this.cityCode,
      departureAtUtc: departureAtUtc ?? this.departureAtUtc,
      reminder: reminder ?? this.reminder,
      notificationId: notificationId,
      syncState: syncState ?? this.syncState,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

DateTime jstCivilDateTimeToUtc({
  required DateTime date,
  required int hour,
  required int minute,
}) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw RangeError('Invalid JST civil time.');
  }
  return DateTime.utc(date.year, date.month, date.day, hour - 9, minute);
}

/// The next whole hour on a JST wall clock.
///
/// A new plan uses this instead of a fixed 09:00 so its first save is always
/// in the future, including late at night when the result rolls to tomorrow.
DateTime nextTravelDepartureOnJstClock(DateTime instant) {
  final nowOnJstClock = instant.toUtc().add(const Duration(hours: 9));
  return DateTime(
    nowOnJstClock.year,
    nowOnJstClock.month,
    nowOnJstClock.day,
    nowOnJstClock.hour + 1,
  );
}

class TravelPlanValidationException implements Exception {
  const TravelPlanValidationException(this.code);

  final String code;
}

class DuplicateTravelPlanException implements Exception {
  const DuplicateTravelPlanException();
}

class TravelPlanLimitException implements Exception {
  const TravelPlanLimitException();
}
