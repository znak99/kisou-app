import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native Firebase auto-init is disabled and daily channel is explicit',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      for (final plistPath in [
        'ios/Runner/Info.plist',
        'ios/Runner/Info-Dev.plist',
      ]) {
        final plist = File(plistPath).readAsStringSync();
        expect(plist, contains('FirebaseMessagingAutoInitEnabled'));
        expect(plist, contains('<false/>'));
        expect(plist, contains('remote-notification'));
      }
      expect(manifest, contains('firebase_messaging_auto_init_enabled'));
      expect(manifest, contains('push_daily_v1'));
    },
  );

  test(
    'display cleanup targets daily push and preserves travel notifications',
    () {
      final android = File(
        'android/app/src/main/kotlin/com/example/kisou_app/MainActivity.kt',
      ).readAsStringSync();
      final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(android, contains('activeNotifications'));
      expect(android, contains('push_daily_v1'));
      expect(android, contains('kisou_daily_push_v1'));
      expect(android, isNot(contains('cancelAll()')));
      expect(android, isNot(contains('cancelAllNotifications')));

      expect(ios, contains('getDeliveredNotifications'));
      expect(ios, contains('kisou_daily_push_v1'));
      expect(ios, contains('removeDeliveredNotifications(withIdentifiers:'));
      expect(ios, isNot(contains('removeAllDeliveredNotifications')));

      final travel = File(
        'lib/services/travel_notification_service.dart',
      ).readAsStringSync();
      expect(travel, contains("channelId = 'travel_departure_v1'"));
      expect(travel, contains("threadIdentifier: 'travel_plans'"));
    },
  );

  test('iOS capabilities declare remote notifications for both flavors', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/Runner-Dev.entitlements',
    ]) {
      final entitlements = File(path).readAsStringSync();
      expect(entitlements, contains('aps-environment'));
    }
  });
}
