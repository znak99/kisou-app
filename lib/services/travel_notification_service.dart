import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest_10y.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../constants/app_strings.dart';
import '../models/travel_plan.dart';

typedef TravelNotificationTapHandler = void Function(int planId);

abstract interface class TravelNotificationGateway {
  Future<void> initialize({TravelNotificationTapHandler? onTap});

  Future<bool> isPermissionGranted();

  Future<bool> requestPermission();

  Future<Set<int>> pendingTravelNotificationIds();

  Future<void> schedule(TravelPlan plan);

  Future<void> cancel(int notificationId);

  Future<bool> openAppSettings();
}

class TravelNotificationService implements TravelNotificationGateway {
  TravelNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'travel_departure_v1';
  static const payloadPrefix = 'travel:';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  TravelNotificationTapHandler? _onTap;

  bool get _isSupportedMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize({TravelNotificationTapHandler? onTap}) {
    _onTap = onTap ?? _onTap;
    if (_initialized || !_isSupportedMobile) {
      _initialized = true;
      return Future<void>.value();
    }
    final inFlight = _initializationFuture;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> initialization;
    initialization = _performInitialize().whenComplete(() {
      if (!_initialized && identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
    _initializationFuture = initialization;
    return initialization;
  }

  Future<void> _performInitialize() async {
    time_zone_data.initializeTimeZones();
    const android = AndroidInitializationSettings('ic_stat_kisou_notification');
    const ios = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handlePayload(launchDetails?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  void _handlePayload(String? payload) {
    final planId = parseTravelNotificationPayload(payload);
    if (planId != null) {
      _onTap?.call(planId);
    }
  }

  @override
  Future<bool> isPermissionGranted() async {
    await initialize();
    if (!_isSupportedMobile) {
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null || await android.areNotificationsEnabled() != true) {
        return false;
      }
      final channels = await android.getNotificationChannels();
      if (channels == null) {
        return true;
      }
      for (final channel in channels) {
        if (channel.id == channelId) {
          return channel.importance != Importance.none;
        }
      }
      // The channel is created lazily with the first scheduled notification.
      return true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final permissions = await ios?.checkPermissions();
    return permissions?.isEnabled == true &&
        permissions?.isAlertEnabled == true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!_isSupportedMobile) {
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? false;
      return granted && await isPermissionGranted();
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await ios?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
    return granted && await isPermissionGranted();
  }

  @override
  Future<Set<int>> pendingTravelNotificationIds() async {
    await initialize();
    if (!_isSupportedMobile) {
      return const {};
    }
    final pending = await _plugin.pendingNotificationRequests();
    return {
      for (final notification in pending)
        if (notification.id >= travelNotificationIdMin &&
            notification.id <= travelNotificationIdMax)
          notification.id,
    };
  }

  @override
  Future<void> schedule(TravelPlan plan) async {
    await initialize();
    final reminderAtUtc = plan.reminderAtUtc;
    if (reminderAtUtc == null) {
      throw StateError('A travel notification requires a reminder time.');
    }
    if (!reminderAtUtc.isAfter(DateTime.now().toUtc())) {
      throw StateError('A past travel notification cannot be scheduled.');
    }
    if (!_isSupportedMobile) {
      return;
    }

    final tokyo = time_zone.getLocation('Asia/Tokyo');
    final scheduledDate = time_zone.TZDateTime.from(reminderAtUtc, tokyo);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        AppStrings.travelPlansTitle,
        channelDescription: AppStrings.travelNotificationGenericBody,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        threadIdentifier: 'travel_plans',
      ),
    );
    await _plugin.zonedSchedule(
      id: plan.notificationId,
      title: AppStrings.travelNotificationGenericTitle,
      body: AppStrings.travelNotificationGenericBody,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$payloadPrefix${plan.id}',
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    if (!_isSupportedMobile) {
      return;
    }
    await _plugin.cancel(id: notificationId);
  }

  @override
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}

int? parseTravelNotificationPayload(String? payload) {
  if (payload == null ||
      !payload.startsWith(TravelNotificationService.payloadPrefix)) {
    return null;
  }
  final rawId = payload.substring(
    TravelNotificationService.payloadPrefix.length,
  );
  final id = int.tryParse(rawId);
  return id != null && id > 0 ? id : null;
}

class MemoryTravelNotificationGateway implements TravelNotificationGateway {
  MemoryTravelNotificationGateway({this.permissionGranted = true});

  bool permissionGranted;
  final Set<int> pendingIds = {};
  TravelNotificationTapHandler? _onTap;

  @override
  Future<void> initialize({TravelNotificationTapHandler? onTap}) async {
    _onTap = onTap ?? _onTap;
  }

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<Set<int>> pendingTravelNotificationIds() async => Set.unmodifiable(
    pendingIds.where(
      (id) => id >= travelNotificationIdMin && id <= travelNotificationIdMax,
    ),
  );

  @override
  Future<void> schedule(TravelPlan plan) async {
    pendingIds.add(plan.notificationId);
  }

  @override
  Future<void> cancel(int notificationId) async {
    pendingIds.remove(notificationId);
  }

  @override
  Future<bool> openAppSettings() async => true;

  void simulateTap(int planId) => _onTap?.call(planId);
}
