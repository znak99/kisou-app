import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/travel_plan.dart';
import '../repositories/travel_plan_repository.dart';
import '../services/travel_notification_service.dart';

final travelPlanRepositoryProvider = Provider<TravelPlanRepository>((ref) {
  late final TravelPlanRepository repository;
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    repository = SqfliteTravelPlanRepository();
  } else {
    repository = MemoryTravelPlanRepository();
  }
  ref.onDispose(() {
    unawaited(repository.close());
  });
  return repository;
});

final travelNotificationGatewayProvider = Provider<TravelNotificationGateway>((
  ref,
) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return TravelNotificationService();
  }
  return MemoryTravelNotificationGateway();
});

final travelPlanProvider =
    AsyncNotifierProvider<TravelPlanController, List<TravelPlan>>(
      TravelPlanController.new,
    );

class TravelPlanController extends AsyncNotifier<List<TravelPlan>> {
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<List<TravelPlan>> build() {
    return _serialized(_build);
  }

  Future<List<TravelPlan>> _build() async {
    try {
      await _reconcile(strict: false);
    } catch (_) {
      // Platform notification availability never blocks offline plan reads.
    }
    return ref.read(travelPlanRepositoryProvider).listVisible();
  }

  Future<TravelPlan> create(
    TravelPlanDraft draft, {
    required bool requestNotificationPermission,
  }) {
    return _serialized(
      () => _create(
        draft,
        requestNotificationPermission: requestNotificationPermission,
      ),
    );
  }

  Future<TravelPlan> _create(
    TravelPlanDraft draft, {
    required bool requestNotificationPermission,
  }) async {
    final repository = ref.read(travelPlanRepositoryProvider);
    final created = await repository.create(draft);
    // A brand-new no-reminder plan cannot have a prior OS notification.
    if (created.reminder != TravelReminder.none) {
      await _syncPlanBestEffort(
        created,
        requestPermission: requestNotificationPermission,
      );
    }
    await _reload();
    return _findVisible(created.id) ?? created;
  }

  Future<TravelPlan> updatePlan(
    int id,
    TravelPlanDraft draft, {
    required bool requestNotificationPermission,
  }) {
    return _serialized(
      () => _updatePlan(
        id,
        draft,
        requestNotificationPermission: requestNotificationPermission,
      ),
    );
  }

  Future<TravelPlan> _updatePlan(
    int id,
    TravelPlanDraft draft, {
    required bool requestNotificationPermission,
  }) async {
    final repository = ref.read(travelPlanRepositoryProvider);
    final updated = await repository.update(id, draft);
    await _syncPlanBestEffort(
      updated,
      requestPermission: requestNotificationPermission,
    );
    await _reload();
    return _findVisible(id) ?? updated;
  }

  Future<void> _syncPlanBestEffort(
    TravelPlan plan, {
    required bool requestPermission,
  }) async {
    try {
      await _syncPlan(
        plan,
        requestPermission: requestPermission,
        strict: false,
      );
    } catch (_) {
      // The SQLite write is the source of truth. Notification platform errors
      // never turn a successfully saved plan into a failed save, which would
      // otherwise make a retry hit the duplicate constraint. Keep an outbox
      // state so startup/resume reconciliation can retry it.
      try {
        // The same durable outbox state covers both scheduling/replacement and
        // cancellation after an existing reminder is changed to "none".
        await ref
            .read(travelPlanRepositoryProvider)
            .setSyncState(plan.id, TravelNotificationSyncState.pendingSchedule);
      } catch (_) {
        // A concurrently deleted plan needs no retry marker.
      }
    }
  }

  TravelPlan? _findVisible(int id) {
    final plans = state.value;
    if (plans == null) {
      return null;
    }
    for (final plan in plans) {
      if (plan.id == id) {
        return plan;
      }
    }
    return null;
  }

  Future<void> delete(int id) {
    return _serialized(() => _delete(id));
  }

  Future<void> _delete(int id) async {
    final repository = ref.read(travelPlanRepositoryProvider);
    final all = await repository.listAll();
    final plan = all.where((item) => item.id == id).firstOrNull;
    if (plan == null) {
      return;
    }
    await repository.markPendingDelete(id);
    try {
      await ref
          .read(travelNotificationGatewayProvider)
          .cancel(plan.notificationId);
      await repository.deletePermanently(id);
    } finally {
      await _reload();
    }
  }

  Future<void> refreshAndReconcile() {
    return _serialized(_refreshAndReconcile);
  }

  Future<void> _refreshAndReconcile() async {
    try {
      await _reconcile(strict: false);
    } catch (_) {
      // Keep refresh useful offline and while the OS notification service is
      // temporarily unavailable. Pending outbox states remain visible.
    }
    await _reload();
  }

  Future<void> retry() {
    return _serialized(_retry);
  }

  Future<void> _retry() async {
    state = const AsyncLoading<List<TravelPlan>>();
    state = await AsyncValue.guard(() async {
      try {
        await _reconcile(strict: false);
      } catch (_) {
        // See [refreshAndReconcile].
      }
      return ref.read(travelPlanRepositoryProvider).listVisible();
    });
  }

  Future<void> _reload() async {
    state = AsyncData(
      await ref.read(travelPlanRepositoryProvider).listVisible(),
    );
  }

  Future<void> _reconcile({required bool strict}) async {
    final repository = ref.read(travelPlanRepositoryProvider);
    final notifications = ref.read(travelNotificationGatewayProvider);
    await notifications.initialize();

    var all = await repository.listAll();
    for (final plan in all) {
      if (plan.syncState == TravelNotificationSyncState.pendingDelete ||
          plan.isExpiredAt(DateTime.now())) {
        try {
          if (plan.syncState != TravelNotificationSyncState.pendingDelete) {
            await repository.markPendingDelete(plan.id);
          }
          await notifications.cancel(plan.notificationId);
          await repository.deletePermanently(plan.id);
        } catch (_) {
          if (strict) {
            rethrow;
          }
        }
      }
    }

    all = await repository.listAll();
    final pendingIds = await notifications.pendingTravelNotificationIds();
    final knownIds = {for (final plan in all) plan.notificationId};
    for (final orphanId in pendingIds.difference(knownIds)) {
      try {
        await notifications.cancel(orphanId);
      } catch (_) {
        if (strict) {
          rethrow;
        }
      }
    }

    for (final plan in all) {
      try {
        await _syncPlan(
          plan,
          requestPermission: false,
          knownPendingIds: pendingIds,
          strict: strict,
        );
      } catch (_) {
        if (strict) {
          rethrow;
        }
      }
    }
  }

  Future<void> _syncPlan(
    TravelPlan plan, {
    required bool requestPermission,
    Set<int>? knownPendingIds,
    required bool strict,
  }) async {
    final repository = ref.read(travelPlanRepositoryProvider);
    final notifications = ref.read(travelNotificationGatewayProvider);

    if (plan.syncState == TravelNotificationSyncState.pendingDelete) {
      await notifications.cancel(plan.notificationId);
      await repository.deletePermanently(plan.id);
      return;
    }

    final reminderAt = plan.reminderAtUtc;
    if (reminderAt == null) {
      await notifications.cancel(plan.notificationId);
      await repository.setSyncState(plan.id, TravelNotificationSyncState.none);
      return;
    }

    final reminderIsFuture = reminderAt.isAfter(DateTime.now().toUtc());
    if (!reminderIsFuture) {
      final pendingIds =
          knownPendingIds ?? await notifications.pendingTravelNotificationIds();
      final permissionGranted = await notifications.isPermissionGranted();
      // Android inexact alarms may legitimately remain pending briefly after
      // their nominal trigger. Preserve a previously scheduled alarm until
      // the OS delivers it or the plan expires, instead of cancelling it on
      // the first resume after the reminder time.
      if (permissionGranted &&
          plan.syncState == TravelNotificationSyncState.scheduled &&
          DateTime.now().toUtc().isBefore(plan.departureAtUtc) &&
          pendingIds.contains(plan.notificationId)) {
        return;
      }
      await notifications.cancel(plan.notificationId);
      await repository.setSyncState(plan.id, TravelNotificationSyncState.none);
      return;
    }

    final permissionGranted = requestPermission
        ? await notifications.requestPermission()
        : await notifications.isPermissionGranted();
    if (!permissionGranted) {
      await notifications.cancel(plan.notificationId);
      await repository.setSyncState(
        plan.id,
        TravelNotificationSyncState.blockedPermission,
      );
      return;
    }

    final pendingIds =
        knownPendingIds ?? await notifications.pendingTravelNotificationIds();
    final needsReplacement =
        plan.syncState == TravelNotificationSyncState.pendingSchedule;
    if (needsReplacement) {
      await notifications.cancel(plan.notificationId);
    }
    if (needsReplacement || !pendingIds.contains(plan.notificationId)) {
      try {
        await notifications.schedule(plan);
      } catch (_) {
        await repository.setSyncState(
          plan.id,
          TravelNotificationSyncState.pendingSchedule,
        );
        if (strict) {
          rethrow;
        }
        return;
      }
    }
    await repository.setSyncState(
      plan.id,
      TravelNotificationSyncState.scheduled,
    );
  }

  /// Removes all device-local travel data and only this feature's pending
  /// notifications. Called before logout/account switch and account deletion.
  Future<void> clearAllLocalData() {
    return _serialized(_clearAllLocalData);
  }

  Future<void> _clearAllLocalData() async {
    final repository = ref.read(travelPlanRepositoryProvider);
    final notifications = ref.read(travelNotificationGatewayProvider);
    await notifications.initialize();
    final plans = await repository.listAll();
    final pendingIds = await notifications.pendingTravelNotificationIds();
    final idsToCancel = {
      ...pendingIds,
      for (final plan in plans) plan.notificationId,
    };
    for (final id in idsToCancel) {
      await notifications.cancel(id);
    }
    await repository.clearAll();
    state = const AsyncData([]);
  }

  Future<bool> openNotificationSettings() {
    return ref.read(travelNotificationGatewayProvider).openAppSettings();
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final scheduled = _operationTail.then(
      (_) => operation(),
      onError: (_, _) => operation(),
    );
    _operationTail = scheduled.then<void>((_) {}, onError: (_, _) {});
    return scheduled;
  }
}

final travelNotificationNavigationProvider =
    NotifierProvider<TravelNotificationNavigationController, int?>(
      TravelNotificationNavigationController.new,
    );

class TravelNotificationNavigationController extends Notifier<int?> {
  @override
  int? build() => null;

  void queue(int planId) {
    if (planId > 0) {
      state = planId;
    }
  }

  int? consume() {
    final value = state;
    state = null;
    return value;
  }
}
