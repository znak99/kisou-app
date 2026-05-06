import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home.dart';
import '../services/home_service.dart';
import 'api_provider.dart';

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

  Future<void> refresh() async {
    final home = await ref.read(homeServiceProvider).getHome();
    state = AsyncData(home);
  }

  Future<void> retry() async {
    state = const AsyncLoading<HomeResponse>();
    state = await AsyncValue.guard(() {
      return ref.read(homeServiceProvider).getHome();
    });
  }
}
