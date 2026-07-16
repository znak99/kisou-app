import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/forecast.dart';
import '../services/forecast_service.dart';
import 'api_provider.dart';

final forecastServiceProvider = Provider<ForecastService>((ref) {
  return ForecastService(ref.watch(apiClientProvider));
});

/// Tomorrow's recommendation for the 予報 tab. Loads on first watch, like the
/// home provider.
final forecastTomorrowProvider =
    AsyncNotifierProvider<ForecastTomorrowController, ForecastTomorrow>(
      ForecastTomorrowController.new,
      retry: (_, _) => null,
    );

class ForecastTomorrowController extends AsyncNotifier<ForecastTomorrow> {
  @override
  Future<ForecastTomorrow> build() {
    return ref.read(forecastServiceProvider).getTomorrow();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      return ref.read(forecastServiceProvider).getTomorrow();
    });
  }

  Future<void> retry() async {
    state = const AsyncLoading<ForecastTomorrow>();
    state = await AsyncValue.guard(() {
      return ref.read(forecastServiceProvider).getTomorrow();
    });
  }
}

/// Date-lookup ("日付で予想") result. Unlike the tab's tomorrow card this is
/// user-triggered: null until the first lookup, then holds the latest result
/// (or its loading/error state) so the card survives tab switches.
final forecastOutlookProvider =
    NotifierProvider<ForecastOutlookController, AsyncValue<ForecastOutlook>?>(
      ForecastOutlookController.new,
    );

class ForecastOutlookController extends Notifier<AsyncValue<ForecastOutlook>?> {
  @override
  AsyncValue<ForecastOutlook>? build() => null;

  Future<void> lookup({
    required String date,
    required double latitude,
    required double longitude,
  }) async {
    state = const AsyncLoading<ForecastOutlook>();
    state = await AsyncValue.guard(() {
      return ref
          .read(forecastServiceProvider)
          .getOutlook(date: date, latitude: latitude, longitude: longitude);
    });
  }

  void clear() {
    state = null;
  }
}
