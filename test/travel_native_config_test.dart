import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/services/travel_notification_service.dart';

void main() {
  test('Android uses inexact reminders with reboot recovery', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final service = File(
      'lib/services/travel_notification_service.dart',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(manifest, isNot(contains('USE_EXACT_ALARM')));
    expect(service, contains('inexactAllowWhileIdle'));
  });

  test('notification ids and payloads stay in the travel namespace', () {
    expect(travelNotificationIdMin, 100000);
    expect(travelNotificationIdMax, 199999);
    expect(TravelNotificationService.payloadPrefix, 'travel:');
  });

  test(
    'notification initialization and Android channel checks are durable',
    () {
      final service = File(
        'lib/services/travel_notification_service.dart',
      ).readAsStringSync();

      expect(service, contains('_initializationFuture'));
      expect(service, contains('getNotificationChannels'));
      expect(service, contains('Importance.none'));
    },
  );

  test('iOS travel storage is protected and excluded from backup', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final directoryService = File(
      'lib/services/travel_database_directory.dart',
    ).readAsStringSync();

    expect(appDelegate, contains('isExcludedFromBackup = true'));
    expect(appDelegate, contains('completeUntilFirstUserAuthentication'));
    expect(appDelegate, contains('TRAVEL_STORAGE_PROTECTION_FAILED'));
    expect(appDelegate, contains('applicationRegistrar.messenger()'));
    expect(appDelegate, contains('migrateLegacyTravelDatabase'));
    expect(appDelegate, contains('"-wal", "-shm"'));
    expect(directoryService, contains('prepareTravelDatabaseDirectory'));
    expect(directoryService, contains('throw StateError'));
  });

  test('authenticated shell reconciles travel plans on cold start', () {
    final rootShell = File('lib/screens/root_shell.dart').readAsStringSync();

    expect(
      rootShell,
      contains('addPostFrameCallback((_) {\n      _reconcileTravelPlans();'),
    );
  });
}
