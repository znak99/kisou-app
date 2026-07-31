import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/api_config.dart';
import 'package:kisou_app/config/ad_config.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/debug/outlook_screenshot_fixture.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/providers/forecast_provider.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/providers/outlook_quota_provider.dart';
import 'package:kisou_app/screens/forecast/outlook_screen.dart';
import 'package:kisou_app/services/forecast_service.dart';
import 'package:kisou_app/services/ad_gateway.dart';
import 'package:kisou_app/utils/jp_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'outlook_quota_date': formatIsoDate(jstToday()),
      'outlook_quota_used': 3,
    });
  });

  test('fixture data is stable apart from the requested date', () {
    final result = buildOutlookScreenshotFixture(date: '2026-08-08');

    expect(result.date, '2026-08-08');
    expect(result.mode, 'forecast');
    expect(result.feeling, 'VERY_HOT');
    expect(result.weather?.tempLow, 26);
    expect(result.weather?.tempHigh, 29);
    expect(result.recommendations, hasLength(1));
    expect(result.recommendations.single.rank, 1);
    expect(result.recommendations.single.outer, isNull);
    expect(result.recommendations.single.top, 'SHORT_SLEEVE');
    expect(result.recommendations.single.bottom, 'SKIRT');
  });

  test('compile-time gate matches debug mode and the explicit define', () {
    const requested = bool.fromEnvironment(
      'OUTLOOK_SCREENSHOT_FIXTURE',
      defaultValue: false,
    );
    expect(
      ApiConfig.outlookScreenshotFixtureEnabled,
      resolveOutlookScreenshotFixtureEnabled(
        debugMode: kDebugMode,
        requested: requested,
      ),
    );
  });

  testWidgets(
    'production-debug opt-in reproduces the outlook result without an API call',
    (tester) async {
      final service = _UnexpectedForecastService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [forecastServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: OutlookScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.forecastOutlookQuota(3)), findsOneWidget);
      expect(find.text(AppStrings.forecastOutlookDateLabel), findsOneWidget);
      expect(
        find.text(formatJpDate(jstToday().add(const Duration(days: 8)))),
        findsOneWidget,
      );
      expect(find.text('東京'), findsOneWidget);

      await tester.tap(find.text(AppStrings.forecastOutlookSubmit));
      await tester.pumpAndSettle();

      expect(service.callCount, 0);
      expect(find.text(AppStrings.forecastOutlookQuota(2)), findsOneWidget);
      expect(
        find.text(AppStrings.forecastFeelingLine('VERY_HOT')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.noOuter), findsOneWidget);
      expect(find.text('半袖'), findsOneWidget);
      expect(find.text('スカート'), findsOneWidget);
      expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
      expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
      expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
      expect(
        find.text(AppStrings.forecastOutlookScreenshotNotice),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.forecastOutlookScreenshotSource),
        findsOneWidget,
      );
      expect(find.text(AppStrings.forecastExplainForecastMode), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !ApiConfig.outlookScreenshotFixtureEnabled,
  );

  test(
    'fixture startup makes zero UMP, SDK, ad, quota, and forecast API calls',
    () async {
      final service = _UnexpectedForecastService();
      final gateway = _UnexpectedAdGateway();
      final container = ProviderContainer(
        overrides: [
          forecastServiceProvider.overrideWithValue(service),
          adGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      expect(AdConfig.enabled, isTrue);
      expect(container.read(adsRuntimePolicyProvider).enabled, isFalse);
      await container.read(adsProvider.notifier).start();
      final quota = await container.read(outlookQuotaProvider.future);
      final result = await container
          .read(forecastOutlookProvider.notifier)
          .lookup(
            date: '2026-08-08',
            cityCode: 'tokyo',
            cityName: '東京',
            latitude: 35.681236,
            longitude: 139.767125,
          );

      expect(result.succeeded, isTrue);
      expect(quota.totalRemaining, 3);
      expect(gateway.calls, 0);
      expect(service.outlookCalls, 0);
      expect(service.quotaCalls, 0);
    },
    skip: !ApiConfig.outlookScreenshotFixtureEnabled || !AdConfig.enabled,
  );
}

class _UnexpectedForecastService extends ForecastService {
  _UnexpectedForecastService() : super(Dio());

  var outlookCalls = 0;
  var quotaCalls = 0;
  int get callCount => outlookCalls;

  @override
  Future<ForecastOutlookResponse> getOutlook({
    required String date,
    required double latitude,
    required double longitude,
    required String idempotencyKey,
  }) {
    outlookCalls++;
    throw StateError('The screenshot fixture must not call the API.');
  }

  @override
  Future<OutlookQuota> getOutlookQuota() {
    quotaCalls++;
    throw StateError('The screenshot fixture must not call the quota API.');
  }
}

class _UnexpectedAdGateway implements AdGateway {
  int calls = 0;

  Never _unexpected() {
    calls++;
    throw StateError('The screenshot fixture must not call AdMob.');
  }

  @override
  Future<bool> canRequestAds() => _unexpected();

  @override
  Future<void> initialize() => _unexpected();

  @override
  Future<bool> isPrivacyOptionsRequired() => _unexpected();

  @override
  Future<void> loadAndShowConsentFormIfRequired() => _unexpected();

  @override
  Future<InlineBannerHandle> loadInlineBanner({
    required int width,
    required String adUnitId,
  }) => _unexpected();

  @override
  Future<RewardedAdHandle> loadRewarded({required String adUnitId}) =>
      _unexpected();

  @override
  Future<void> requestConsentInfoUpdate() => _unexpected();

  @override
  Future<void> showPrivacyOptionsForm() => _unexpected();
}
