import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/widget_recommendation_coordinator.dart';
import '../services/widget_recommendation_service.dart';
import '../services/widget_snapshot_gateway.dart';
import 'api_provider.dart';

final widgetSnapshotGatewayProvider = Provider<WidgetSnapshotGateway>((ref) {
  return MethodChannelWidgetSnapshotGateway();
});

final widgetRecommendationServiceProvider =
    Provider<WidgetRecommendationService>((ref) {
      return WidgetRecommendationService(ref.watch(apiClientProvider));
    });

final widgetRecommendationCoordinatorProvider =
    Provider<WidgetRecommendationCoordinator>((ref) {
      final coordinator = WidgetRecommendationCoordinator(
        service: ref.watch(widgetRecommendationServiceProvider),
        gateway: ref.watch(widgetSnapshotGatewayProvider),
      );
      ref.onDispose(coordinator.deactivate);
      return coordinator;
    });

final widgetRecommendationStartupSyncProvider =
    FutureProvider.autoDispose<WidgetRefreshResult>((ref) {
      return ref.watch(widgetRecommendationCoordinatorProvider).refreshIfDue();
    });

final widgetHomeRouteProvider =
    NotifierProvider<WidgetHomeRouteController, bool>(
      WidgetHomeRouteController.new,
    );

class WidgetHomeRouteController extends Notifier<bool> {
  var _initialized = false;

  @override
  bool build() {
    final gateway = ref.read(widgetSnapshotGatewayProvider);
    ref.onDispose(() {
      gateway.setHomeRouteHandler(null);
    });
    if (!_initialized) {
      _initialized = true;
      Future.microtask(() => _initialize(gateway)).catchError((_) {});
    }
    return false;
  }

  Future<void> _initialize(WidgetSnapshotGateway gateway) async {
    if (!ref.mounted) return;
    gateway.setHomeRouteHandler(queue);
    try {
      final pending = await gateway.consumeInitialHomeRoute();
      if (!ref.mounted) return;
      if (pending) queue();
    } catch (_) {
      // A route is a convenience only. Authentication and widget snapshot
      // cleanup must remain usable when native route delivery is unavailable.
    }
  }

  void queue() {
    if (ref.mounted) {
      state = true;
    }
  }

  void consume() {
    if (state) {
      state = false;
    }
  }

  void clear() {
    state = false;
  }
}
