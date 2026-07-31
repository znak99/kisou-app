import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/providers/forecast_provider.dart';
import 'package:kisou_app/providers/outlook_quota_provider.dart';
import 'package:kisou_app/services/forecast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads server quota and removes legacy device counters', () async {
    SharedPreferences.setMockInitialValues({
      'outlook_quota_date': '2026-07-31',
      'outlook_quota_used': 3,
    });
    final service = _QuotaForecastService()..quotaResult = _quota(2);
    final container = ProviderContainer(
      overrides: [forecastServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final quota = await container.read(outlookQuotaProvider.future);
    final preferences = await SharedPreferences.getInstance();

    expect(quota.totalRemaining, 2);
    expect(preferences.containsKey('outlook_quota_date'), isFalse);
    expect(preferences.containsKey('outlook_quota_used'), isFalse);
  });

  test('late initial GET cannot overwrite newer POST response quota', () async {
    SharedPreferences.setMockInitialValues({});
    final initial = Completer<OutlookQuota>();
    final service = _QuotaForecastService()..quotaFuture = initial.future;
    final container = ProviderContainer(
      overrides: [forecastServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final loading = container.read(outlookQuotaProvider.future);
    await Future<void>.delayed(Duration.zero);
    container.read(outlookQuotaProvider.notifier).applyServerQuota(_quota(1));
    initial.complete(_quota(3));
    await loading;
    await Future<void>.delayed(Duration.zero);

    expect(container.read(outlookQuotaProvider).requireValue.totalRemaining, 1);
  });
}

class _QuotaForecastService extends ForecastService {
  _QuotaForecastService() : super(Dio());

  OutlookQuota? quotaResult;
  Future<OutlookQuota>? quotaFuture;

  @override
  Future<OutlookQuota> getOutlookQuota() {
    return quotaFuture ?? Future.value(quotaResult!);
  }
}

OutlookQuota _quota(int remaining) {
  return OutlookQuota(
    date: '2026-07-31',
    freeLimit: 3,
    freeUsed: 3 - remaining,
    freeRemaining: remaining,
    rewardCredits: 0,
    totalRemaining: remaining,
    resetsAt: DateTime.utc(2026, 7, 31, 15),
    adsAvailable: remaining == 0,
  );
}
