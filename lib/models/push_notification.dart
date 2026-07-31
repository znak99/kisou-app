enum PushNotificationType { morningRecommendation, eveningFeedback }

class PushRemoteMessage {
  const PushRemoteMessage({required this.data});

  final Map<String, String> data;
}

class PushNotificationIntent {
  const PushNotificationIntent({
    required this.type,
    required this.deliveryId,
    required this.clientRevision,
  });

  factory PushNotificationIntent.fromData(Map<String, String> data) {
    if (data.length != 4 ||
        !data.keys.toSet().containsAll(const {
          'schema_version',
          'type',
          'delivery_id',
          'client_revision',
        }) ||
        data['schema_version'] != '1') {
      throw const FormatException('Unsupported push payload.');
    }
    final type = switch (data['type']) {
      'morning_recommendation' => PushNotificationType.morningRecommendation,
      'evening_feedback' => PushNotificationType.eveningFeedback,
      _ => throw const FormatException('Unsupported push type.'),
    };
    final deliveryId = data['delivery_id'];
    if (deliveryId == null || !_uuidV4Pattern.hasMatch(deliveryId)) {
      throw const FormatException('Invalid push delivery identifier.');
    }
    final encodedRevision = data['client_revision'];
    if (encodedRevision == null ||
        !_clientRevisionPattern.hasMatch(encodedRevision)) {
      throw const FormatException('Invalid push client revision.');
    }
    final clientRevision = int.tryParse(encodedRevision);
    if (clientRevision == null ||
        clientRevision < 1 ||
        clientRevision > maxPushClientRevision) {
      throw const FormatException('Invalid push client revision.');
    }
    return PushNotificationIntent(
      type: type,
      deliveryId: deliveryId,
      clientRevision: clientRevision,
    );
  }

  static const maxPushClientRevision = 0x7fffffffffffffff;

  final PushNotificationType type;
  final String deliveryId;
  final int clientRevision;
}

enum PushPermissionState {
  notDetermined,
  allowed,
  denied,
  blocked,
  unavailable,
}

enum PushPlatformAuthorization {
  notDetermined,
  authorized,
  provisional,
  denied,
}

class PushPreferences {
  const PushPreferences({
    required this.morningEnabled,
    required this.morningTime,
    required this.eveningEnabled,
    required this.eveningTime,
  });

  factory PushPreferences.fromJson(Map<String, dynamic> json) {
    if (json.length != 5 ||
        json.keys.toSet().difference(const {
          'morning_enabled',
          'morning_time',
          'evening_enabled',
          'evening_time',
          'timezone',
        }).isNotEmpty ||
        json['morning_enabled'] is! bool ||
        json['evening_enabled'] is! bool ||
        json['morning_time'] is! String ||
        json['evening_time'] is! String ||
        json['timezone'] != timezone) {
      throw const FormatException('Invalid push preferences.');
    }
    return PushPreferences(
      morningEnabled: json['morning_enabled'] as bool,
      morningTime: parseNotificationTime(json['morning_time'] as String),
      eveningEnabled: json['evening_enabled'] as bool,
      eveningTime: parseNotificationTime(json['evening_time'] as String),
    );
  }

  static const timezone = 'Asia/Tokyo';
  static const defaults = PushPreferences(
    morningEnabled: false,
    morningTime: NotificationTime(hour: 7, minute: 0),
    eveningEnabled: false,
    eveningTime: NotificationTime(hour: 20, minute: 0),
  );

  final bool morningEnabled;
  final NotificationTime morningTime;
  final bool eveningEnabled;
  final NotificationTime eveningTime;

  bool get anyEnabled => morningEnabled || eveningEnabled;

  PushPreferences copyWith({
    bool? morningEnabled,
    NotificationTime? morningTime,
    bool? eveningEnabled,
    NotificationTime? eveningTime,
  }) {
    return PushPreferences(
      morningEnabled: morningEnabled ?? this.morningEnabled,
      morningTime: morningTime ?? this.morningTime,
      eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      eveningTime: eveningTime ?? this.eveningTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'morning_enabled': morningEnabled,
      'morning_time': morningTime.apiValue,
      'evening_enabled': eveningEnabled,
      'evening_time': eveningTime.apiValue,
      'timezone': timezone,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PushPreferences &&
        other.morningEnabled == morningEnabled &&
        other.morningTime == morningTime &&
        other.eveningEnabled == eveningEnabled &&
        other.eveningTime == eveningTime;
  }

  @override
  int get hashCode =>
      Object.hash(morningEnabled, morningTime, eveningEnabled, eveningTime);
}

class NotificationTime {
  const NotificationTime({required this.hour, required this.minute})
    : assert(hour >= 0 && hour <= 23),
      assert(minute >= 0 && minute <= 59);

  final int hour;
  final int minute;

  String get apiValue =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) {
    return other is NotificationTime &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}

NotificationTime parseNotificationTime(String value) {
  if (!_timePattern.hasMatch(value)) {
    throw const FormatException('Invalid notification time.');
  }
  return NotificationTime(
    hour: int.parse(value.substring(0, 2)),
    minute: int.parse(value.substring(3, 5)),
  );
}

final _timePattern = RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$');
final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _clientRevisionPattern = RegExp(r'^[1-9][0-9]{0,18}$');
