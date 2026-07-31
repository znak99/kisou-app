import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/outlook_quota.dart';
import '../utils/jp_date.dart';
import 'forecast_service_provider.dart';

const _legacyQuotaDateKey = 'outlook_quota_date';
const _legacyQuotaUsedKey = 'outlook_quota_used';

final outlookQuotaProvider =
    AsyncNotifierProvider<OutlookQuotaController, OutlookQuota>(
      OutlookQuotaController.new,
      retry: (_, _) => null,
    );

class OutlookQuotaController extends AsyncNotifier<OutlookQuota> {
  int _revision = 0;

  @override
  Future<OutlookQuota> build() async {
    if (ApiConfig.outlookScreenshotFixtureEnabled) {
      return OutlookQuota.screenshotFixture(formatIsoDate(jstToday()));
    }
    await _removeLegacyLocalQuota();
    final revision = _revision;
    final quota = await ref.read(forecastServiceProvider).getOutlookQuota();
    return revision == _revision ? quota : state.value ?? quota;
  }

  Future<void> refresh() async {
    await refreshFromServer();
  }

  /// Refreshes the authoritative quota and reports whether a new server value
  /// was applied. Existing UI data is preserved when the request fails.
  Future<bool> refreshFromServer() async {
    if (ApiConfig.outlookScreenshotFixtureEnabled) {
      return true;
    }
    final revision = ++_revision;
    final previous = state.value;
    try {
      final quota = await ref.read(forecastServiceProvider).getOutlookQuota();
      if (revision == _revision) {
        state = AsyncData(quota);
      }
      return revision == _revision;
    } catch (error, stackTrace) {
      if (revision == _revision) {
        state = previous == null
            ? AsyncError(error, stackTrace)
            : AsyncData(previous);
      }
      return false;
    }
  }

  void applyServerQuota(OutlookQuota quota) {
    _revision++;
    state = AsyncData(quota);
  }

  Future<void> _removeLegacyLocalQuota() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.remove(_legacyQuotaDateKey),
        preferences.remove(_legacyQuotaUsedKey),
      ]);
    } catch (_) {
      // Quota is server-authoritative. A local migration failure must not
      // block it, and a later provider rebuild retries removal.
    }
  }
}
