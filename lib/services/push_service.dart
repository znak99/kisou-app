import 'package:dio/dio.dart';

import '../config/push_config.dart';
import '../models/push_notification.dart';

abstract interface class PushApiGateway {
  Future<PushPreferences> getPreferences();

  Future<PushPreferences> updatePreferences(PushPreferences preferences);

  Future<void> registerDevice({
    required String installationId,
    required int clientRevision,
    required KisouPushPlatform platform,
    required String fcmToken,
    required String appVersion,
  });

  Future<void> unregisterDevice({
    required String installationId,
    required int clientRevision,
    bool suppressAuthRecovery = false,
  });
}

class PushService implements PushApiGateway {
  const PushService(this._dio);

  final Dio _dio;

  @override
  Future<PushPreferences> getPreferences() async {
    final response = await _dio.get<Map<String, dynamic>>('/push/preferences');
    final data = response.data;
    if (response.statusCode != 200 || data == null) {
      throw const PushServiceException('Push preferences response is empty.');
    }
    return PushPreferences.fromJson(data);
  }

  @override
  Future<PushPreferences> updatePreferences(PushPreferences preferences) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/push/preferences',
      data: preferences.toJson(),
    );
    final data = response.data;
    if (response.statusCode != 200 || data == null) {
      throw const PushServiceException('Push preferences response is empty.');
    }
    return PushPreferences.fromJson(data);
  }

  @override
  Future<void> registerDevice({
    required String installationId,
    required int clientRevision,
    required KisouPushPlatform platform,
    required String fcmToken,
    required String appVersion,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/push/devices',
      data: {
        'installation_id': installationId,
        'client_revision': clientRevision,
        'platform': platform.name,
        'fcm_token': fcmToken,
        'app_version': appVersion,
      },
    );
    final data = response.data;
    if (response.statusCode != 200 ||
        data == null ||
        data.length != 5 ||
        !data.keys.toSet().containsAll(const {
          'installation_id',
          'client_revision',
          'platform',
          'active',
          'registered_at',
        }) ||
        data['installation_id'] != installationId ||
        data['client_revision'] is! int ||
        data['client_revision'] as int != clientRevision ||
        data['platform'] != platform.name ||
        data['active'] != true ||
        !_isUtcTimestamp(data['registered_at'])) {
      throw const PushServiceException('Invalid push registration response.');
    }
  }

  @override
  Future<void> unregisterDevice({
    required String installationId,
    required int clientRevision,
    bool suppressAuthRecovery = false,
  }) async {
    final response = await _dio.post<void>(
      '/push/devices/unregister',
      data: {
        'installation_id': installationId,
        'client_revision': clientRevision,
      },
      options: Options(extra: {'suppressAuthRecovery': suppressAuthRecovery}),
    );
    if (response.statusCode != 204) {
      throw const PushServiceException('Invalid push unregister response.');
    }
  }
}

class PushServiceException implements Exception {
  const PushServiceException(this.message);

  final String message;
}

bool _isUtcTimestamp(Object? value) {
  if (value is! String) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.isUtc;
}
