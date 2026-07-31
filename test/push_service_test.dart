import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/push_config.dart';
import 'package:kisou_app/models/push_notification.dart';
import 'package:kisou_app/services/push_service.dart';

const _installationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  test('preferences use the exact JST request and response contract', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'morning_enabled': true,
                  'morning_time': '07:30',
                  'evening_enabled': false,
                  'evening_time': '20:15',
                  'timezone': 'Asia/Tokyo',
                },
              ),
            );
          },
        ),
      );
    final preferences = const PushPreferences(
      morningEnabled: true,
      morningTime: NotificationTime(hour: 7, minute: 30),
      eveningEnabled: false,
      eveningTime: NotificationTime(hour: 20, minute: 15),
    );

    final result = await PushService(dio).updatePreferences(preferences);

    expect(captured.method, 'PUT');
    expect(captured.path, '/push/preferences');
    expect(captured.data, preferences.toJson());
    expect(result, preferences);
  });

  test('preferences reject extra response fields', () async {
    final dio = _responseDio({
      'morning_enabled': false,
      'morning_time': '07:00',
      'evening_enabled': false,
      'evening_time': '20:00',
      'timezone': 'Asia/Tokyo',
      'unexpected': true,
    });

    await expectLater(PushService(dio).getPreferences(), throwsFormatException);
  });

  test(
    'device registration sends and accepts only the exact contract',
    () async {
      late RequestOptions captured;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'installation_id': _installationId,
                    'client_revision': 7,
                    'platform': 'android',
                    'active': true,
                    'registered_at': '2026-07-31T01:02:03Z',
                  },
                ),
              );
            },
          ),
        );

      await PushService(dio).registerDevice(
        installationId: _installationId,
        clientRevision: 7,
        platform: KisouPushPlatform.android,
        fcmToken: 'raw-token-only-in-request-memory',
        appVersion: '1.2.3+45',
      );

      expect(captured.method, 'PUT');
      expect(captured.path, '/push/devices');
      expect(captured.data, {
        'installation_id': _installationId,
        'client_revision': 7,
        'platform': 'android',
        'fcm_token': 'raw-token-only-in-request-memory',
        'app_version': '1.2.3+45',
      });
    },
  );

  test(
    'device registration rejects loose revision and response fields',
    () async {
      final looseRevision = _responseDio({
        'installation_id': _installationId,
        'client_revision': 7.0,
        'platform': 'android',
        'active': true,
        'registered_at': '2026-07-31T01:02:03Z',
      });
      await expectLater(
        PushService(looseRevision).registerDevice(
          installationId: _installationId,
          clientRevision: 7,
          platform: KisouPushPlatform.android,
          fcmToken: 'token',
          appVersion: '1.0.0+1',
        ),
        throwsA(isA<PushServiceException>()),
      );

      final extraField = _responseDio({
        'installation_id': _installationId,
        'client_revision': 7,
        'platform': 'android',
        'active': true,
        'registered_at': '2026-07-31T01:02:03+00:00',
        'unexpected': true,
      });
      await expectLater(
        PushService(extraField).registerDevice(
          installationId: _installationId,
          clientRevision: 7,
          platform: KisouPushPlatform.android,
          fcmToken: 'token',
          appVersion: '1.0.0+1',
        ),
        throwsA(isA<PushServiceException>()),
      );
    },
  );

  test('unregister sends the revision and auth-recovery guard', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204),
            );
          },
        ),
      );

    await PushService(dio).unregisterDevice(
      installationId: _installationId,
      clientRevision: 8,
      suppressAuthRecovery: true,
    );

    expect(captured.method, 'POST');
    expect(captured.path, '/push/devices/unregister');
    expect(captured.data, {
      'installation_id': _installationId,
      'client_revision': 8,
    });
    expect(captured.extra['suppressAuthRecovery'], isTrue);
  });
}

Dio _responseDio(Map<String, dynamic> data) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );
}
