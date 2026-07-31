import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home.dart';
import '../services/home_service.dart';
import 'api_provider.dart';
import 'widget_recommendation_provider.dart';

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(ref.watch(apiClientProvider));
});

final homeProvider = AsyncNotifierProvider<HomeController, HomeResponse>(
  HomeController.new,
  retry: (_, _) => null,
);

class HomeController extends AsyncNotifier<HomeResponse> {
  @override
  Future<HomeResponse> build() {
    return ref.read(homeServiceProvider).getHome();
  }

  Future<void> refresh({bool syncWidget = true}) async {
    state = await AsyncValue.guard(() {
      return ref.read(homeServiceProvider).getHome();
    });
    if (syncWidget && state.hasValue) {
      unawaited(
        ref
            .read(widgetRecommendationCoordinatorProvider)
            .refreshIfDue(force: true),
      );
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading<HomeResponse>();
    state = await AsyncValue.guard(() {
      return ref.read(homeServiceProvider).getHome();
    });
    if (state.hasValue) {
      unawaited(
        ref
            .read(widgetRecommendationCoordinatorProvider)
            .refreshIfDue(force: true),
      );
    }
  }
}
