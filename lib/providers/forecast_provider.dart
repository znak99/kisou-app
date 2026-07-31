import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../debug/outlook_screenshot_fixture.dart';
import '../models/forecast.dart';
import 'forecast_service_provider.dart';
import 'outlook_quota_provider.dart';

export 'forecast_service_provider.dart' show forecastServiceProvider;

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
    NotifierProvider<
      ForecastOutlookController,
      AsyncValue<ForecastOutlookResult>?
    >(ForecastOutlookController.new);

class ForecastOutlookResult {
  const ForecastOutlookResult({
    required this.outlook,
    required this.cityCode,
    required this.cityName,
  });

  final ForecastOutlook outlook;
  final String cityCode;
  final String cityName;
}

class OutlookLookupOutcome {
  const OutlookLookupOutcome._({required this.succeeded, this.error});

  const OutlookLookupOutcome.success() : this._(succeeded: true);

  const OutlookLookupOutcome.failure(Object error)
    : this._(succeeded: false, error: error);

  final bool succeeded;
  final Object? error;
}

final outlookIdempotencyKeyFactoryProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});

class ForecastOutlookController
    extends Notifier<AsyncValue<ForecastOutlookResult>?> {
  String? _pendingRequestSignature;
  String? _pendingIdempotencyKey;

  @override
  AsyncValue<ForecastOutlookResult>? build() => null;

  /// Runs a lookup with one UUID per semantic request. Network/timeout retries
  /// reuse that UUID, while a changed input or a success starts a new operation.
  Future<OutlookLookupOutcome> lookup({
    required String date,
    required String cityCode,
    required String cityName,
    required double latitude,
    required double longitude,
  }) async {
    if (ApiConfig.outlookScreenshotFixtureEnabled) {
      state = AsyncData(
        ForecastOutlookResult(
          outlook: buildOutlookScreenshotFixture(date: date),
          cityCode: cityCode,
          cityName: cityName,
        ),
      );
      return const OutlookLookupOutcome.success();
    }

    final signature = '$date|${latitude.toString()}|${longitude.toString()}';
    if (_pendingRequestSignature != signature ||
        _pendingIdempotencyKey == null) {
      _pendingRequestSignature = signature;
      _pendingIdempotencyKey = ref.read(outlookIdempotencyKeyFactoryProvider)();
    }
    final idempotencyKey = _pendingIdempotencyKey!;
    final previous = state;
    if (previous?.value == null) {
      state = const AsyncLoading<ForecastOutlookResult>();
    }
    try {
      final response = await ref
          .read(forecastServiceProvider)
          .getOutlook(
            date: date,
            latitude: latitude,
            longitude: longitude,
            idempotencyKey: idempotencyKey,
          );
      state = AsyncData(
        ForecastOutlookResult(
          outlook: response.outlook,
          cityCode: cityCode,
          cityName: cityName,
        ),
      );
      ref.read(outlookQuotaProvider.notifier).applyServerQuota(response.quota);
      _pendingRequestSignature = null;
      _pendingIdempotencyKey = null;
      return const OutlookLookupOutcome.success();
    } catch (error, stackTrace) {
      if (error is DioException &&
          (error.response?.statusCode == 409 ||
              error.response?.statusCode == 429)) {
        await ref.read(outlookQuotaProvider.notifier).refresh();
        if (error.response?.statusCode == 409) {
          resetPendingOperation();
        }
      }
      if (previous?.value case final value?) {
        state = AsyncData(value);
      } else {
        state = AsyncError(error, stackTrace);
      }
      return OutlookLookupOutcome.failure(error);
    }
  }

  void clear() {
    state = null;
    resetPendingOperation();
  }

  void resetPendingOperation() {
    _pendingRequestSignature = null;
    _pendingIdempotencyKey = null;
  }
}
