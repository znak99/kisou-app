import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/providers/travel_plan_provider.dart';
import 'package:kisou_app/repositories/travel_plan_repository.dart';
import 'package:kisou_app/services/travel_notification_service.dart';

void main() {
  late MemoryTravelPlanRepository repository;
  late _ControllableNotificationGateway notifications;
  late ProviderContainer container;

  setUp(() {
    repository = MemoryTravelPlanRepository(
      now: () => DateTime.utc(2026, 7, 31),
    );
    notifications = _ControllableNotificationGateway();
    container = ProviderContainer(
      overrides: [
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'notification failure does not turn a saved plan into a failed save',
    () async {
      notifications.failScheduling = true;
      await container.read(travelPlanProvider.future);

      final saved = await container
          .read(travelPlanProvider.notifier)
          .create(
            _draft(reminder: TravelReminder.dayBefore),
            requestNotificationPermission: true,
          );

      expect(saved.syncState, TravelNotificationSyncState.pendingSchedule);
      expect(await repository.listVisible(), hasLength(1));
    },
  );

  test('permission denial stores a visible blocked state', () async {
    notifications.permissionGranted = false;
    await container.read(travelPlanProvider.future);

    final saved = await container
        .read(travelPlanProvider.notifier)
        .create(
          _draft(reminder: TravelReminder.threeHoursBefore),
          requestNotificationPermission: true,
        );

    expect(saved.syncState, TravelNotificationSyncState.blockedPermission);
    expect(notifications.requestCount, 1);
  });

  test(
    'startup and a no-reminder save never request notification permission',
    () async {
      notifications.permissionGranted = false;

      await container.read(travelPlanProvider.future);
      await container
          .read(travelPlanProvider.notifier)
          .create(
            _draft(reminder: TravelReminder.none),
            requestNotificationPermission: false,
          );

      expect(notifications.requestCount, 0);
    },
  );

  test('resume reconciliation retries a pending outbox plan', () async {
    notifications.failScheduling = true;
    await container.read(travelPlanProvider.future);
    final saved = await container
        .read(travelPlanProvider.notifier)
        .create(
          _draft(reminder: TravelReminder.dayBefore),
          requestNotificationPermission: true,
        );
    notifications.failScheduling = false;

    await container.read(travelPlanProvider.notifier).refreshAndReconcile();

    final reconciled = container
        .read(travelPlanProvider)
        .requireValue
        .singleWhere((plan) => plan.id == saved.id);
    expect(reconciled.syncState, TravelNotificationSyncState.scheduled);
    expect(notifications.pendingIds, contains(saved.notificationId));
  });

  test('an update remains saved when replacement scheduling fails', () async {
    await container.read(travelPlanProvider.future);
    final original = await container
        .read(travelPlanProvider.notifier)
        .create(
          _draft(reminder: TravelReminder.none),
          requestNotificationPermission: false,
        );
    notifications.failScheduling = true;

    final updated = await container
        .read(travelPlanProvider.notifier)
        .updatePlan(
          original.id,
          TravelPlanDraft(
            cityCode: 'osaka',
            departureAtUtc: DateTime.utc(2030, 8, 11),
            reminder: TravelReminder.dayBefore,
          ),
          requestNotificationPermission: true,
        );

    expect(updated.cityCode, 'osaka');
    expect(updated.departureAtUtc, DateTime.utc(2030, 8, 11));
    expect(updated.syncState, TravelNotificationSyncState.pendingSchedule);
  });

  test(
    'removing a reminder keeps a cancellation outbox when cancellation fails',
    () async {
      await container.read(travelPlanProvider.future);
      final original = await container
          .read(travelPlanProvider.notifier)
          .create(
            _draft(reminder: TravelReminder.dayBefore),
            requestNotificationPermission: true,
          );
      notifications.failCancellation = true;

      final updated = await container
          .read(travelPlanProvider.notifier)
          .updatePlan(
            original.id,
            _draft(reminder: TravelReminder.none),
            requestNotificationPermission: false,
          );

      expect(updated.reminder, TravelReminder.none);
      expect(updated.syncState, TravelNotificationSyncState.pendingSchedule);
      expect(notifications.pendingIds, contains(original.notificationId));

      notifications.failCancellation = false;
      await container.read(travelPlanProvider.notifier).refreshAndReconcile();

      final reconciled = (await repository.listVisible()).single;
      expect(reconciled.syncState, TravelNotificationSyncState.none);
      expect(
        notifications.pendingIds,
        isNot(contains(original.notificationId)),
      );
    },
  );

  test(
    'a failed delete cancellation stays hidden and reconciles later',
    () async {
      await container.read(travelPlanProvider.future);
      final saved = await container
          .read(travelPlanProvider.notifier)
          .create(
            _draft(reminder: TravelReminder.none),
            requestNotificationPermission: false,
          );
      notifications.failCancellation = true;

      await expectLater(
        container.read(travelPlanProvider.notifier).delete(saved.id),
        throwsStateError,
      );

      expect(container.read(travelPlanProvider).requireValue, isEmpty);
      expect(
        (await repository.listAll()).single.syncState,
        TravelNotificationSyncState.pendingDelete,
      );

      notifications.failCancellation = false;
      await container.read(travelPlanProvider.notifier).refreshAndReconcile();
      expect(await repository.listAll(), isEmpty);
    },
  );

  test('clear removes plans and only reserved travel notifications', () async {
    await container.read(travelPlanProvider.future);
    final saved = await container
        .read(travelPlanProvider.notifier)
        .create(
          _draft(reminder: TravelReminder.dayBefore),
          requestNotificationPermission: true,
        );
    notifications.pendingIds.add(7);

    await container.read(travelPlanProvider.notifier).clearAllLocalData();

    expect(await repository.listAll(), isEmpty);
    expect(notifications.pendingIds, contains(7));
    expect(notifications.pendingIds, isNot(contains(saved.notificationId)));
  });

  test('reconciliation cannot overwrite a concurrent plan update', () async {
    await container.read(travelPlanProvider.future);
    final original = await repository.create(
      _draft(reminder: TravelReminder.dayBefore),
    );
    notifications.pauseNextPendingRead();

    final refresh = container
        .read(travelPlanProvider.notifier)
        .refreshAndReconcile();
    await notifications.pendingReadStarted.future;
    var updateCompleted = false;
    final newDeparture = DateTime.utc(2030, 8, 12);
    final update = container
        .read(travelPlanProvider.notifier)
        .updatePlan(
          original.id,
          TravelPlanDraft(
            cityCode: 'osaka',
            departureAtUtc: newDeparture,
            reminder: TravelReminder.dayBefore,
          ),
          requestNotificationPermission: true,
        )
        .whenComplete(() => updateCompleted = true);

    await Future<void>.delayed(Duration.zero);
    expect(updateCompleted, isFalse);
    notifications.releasePendingRead();
    await Future.wait([refresh, update]);

    expect(notifications.scheduledDepartures.last, newDeparture);
    expect((await repository.listVisible()).single.cityCode, 'osaka');
  });

  test('a delayed inexact alarm remains pending until departure', () async {
    final now = DateTime.now().toUtc();
    final delayedRepository = MemoryTravelPlanRepository(
      now: () => now.subtract(const Duration(days: 1)),
    );
    final delayedNotifications = _ControllableNotificationGateway();
    final delayedContainer = ProviderContainer(
      overrides: [
        travelPlanRepositoryProvider.overrideWithValue(delayedRepository),
        travelNotificationGatewayProvider.overrideWithValue(
          delayedNotifications,
        ),
      ],
    );
    addTearDown(delayedContainer.dispose);
    await delayedContainer.read(travelPlanProvider.future);
    final plan = await delayedRepository.create(
      TravelPlanDraft(
        cityCode: 'tokyo',
        departureAtUtc: now.add(const Duration(hours: 1)),
        reminder: TravelReminder.threeHoursBefore,
      ),
    );
    await delayedRepository.setSyncState(
      plan.id,
      TravelNotificationSyncState.scheduled,
    );
    delayedNotifications.pendingIds.add(plan.notificationId);

    await delayedContainer
        .read(travelPlanProvider.notifier)
        .refreshAndReconcile();

    expect(delayedNotifications.pendingIds, contains(plan.notificationId));
    expect(
      (await delayedRepository.listVisible()).single.syncState,
      TravelNotificationSyncState.scheduled,
    );
  });

  test('a delayed alarm is cancelled once departure has passed', () async {
    final now = DateTime.now().toUtc();
    final delayedRepository = MemoryTravelPlanRepository(
      now: () => now.subtract(const Duration(days: 1)),
    );
    final delayedNotifications = _ControllableNotificationGateway();
    final delayedContainer = ProviderContainer(
      overrides: [
        travelPlanRepositoryProvider.overrideWithValue(delayedRepository),
        travelNotificationGatewayProvider.overrideWithValue(
          delayedNotifications,
        ),
      ],
    );
    addTearDown(delayedContainer.dispose);
    await delayedContainer.read(travelPlanProvider.future);
    final plan = await delayedRepository.create(
      TravelPlanDraft(
        cityCode: 'tokyo',
        departureAtUtc: now.subtract(const Duration(minutes: 1)),
        reminder: TravelReminder.threeHoursBefore,
      ),
    );
    await delayedRepository.setSyncState(
      plan.id,
      TravelNotificationSyncState.scheduled,
    );
    delayedNotifications.pendingIds.add(plan.notificationId);

    await delayedContainer
        .read(travelPlanProvider.notifier)
        .refreshAndReconcile();

    expect(
      delayedNotifications.pendingIds,
      isNot(contains(plan.notificationId)),
    );
    expect(
      (await delayedRepository.listVisible()).single.syncState,
      TravelNotificationSyncState.none,
    );
  });
}

TravelPlanDraft _draft({required TravelReminder reminder}) {
  return TravelPlanDraft(
    cityCode: 'tokyo',
    departureAtUtc: DateTime.utc(2030, 8, 10),
    reminder: reminder,
  );
}

class _ControllableNotificationGateway extends MemoryTravelNotificationGateway {
  bool failScheduling = false;
  bool failCancellation = false;
  int requestCount = 0;
  Completer<void> pendingReadStarted = Completer<void>();
  Completer<void>? _pendingReadRelease;
  final List<DateTime> scheduledDepartures = [];

  void pauseNextPendingRead() {
    pendingReadStarted = Completer<void>();
    _pendingReadRelease = Completer<void>();
  }

  void releasePendingRead() {
    _pendingReadRelease?.complete();
    _pendingReadRelease = null;
  }

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    return super.requestPermission();
  }

  @override
  Future<void> schedule(TravelPlan plan) async {
    if (failScheduling) {
      throw StateError('platform scheduler unavailable');
    }
    scheduledDepartures.add(plan.departureAtUtc);
    await super.schedule(plan);
  }

  @override
  Future<Set<int>> pendingTravelNotificationIds() async {
    final release = _pendingReadRelease;
    if (release != null) {
      if (!pendingReadStarted.isCompleted) {
        pendingReadStarted.complete();
      }
      await release.future;
    }
    return super.pendingTravelNotificationIds();
  }

  @override
  Future<void> cancel(int notificationId) async {
    if (failCancellation) {
      throw StateError('platform cancellation unavailable');
    }
    await super.cancel(notificationId);
  }
}
