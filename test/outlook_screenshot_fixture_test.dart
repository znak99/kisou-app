import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/api_config.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/debug/outlook_screenshot_fixture.dart';
import 'package:kisou_app/models/forecast.dart';
import 'package:kisou_app/providers/forecast_provider.dart';
import 'package:kisou_app/screens/forecast/outlook_screen.dart';
import 'package:kisou_app/services/forecast_service.dart';
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
}

class _UnexpectedForecastService extends ForecastService {
  _UnexpectedForecastService() : super(Dio());

  var callCount = 0;

  @override
  Future<ForecastOutlook> getOutlook({
    required String date,
    required double latitude,
    required double longitude,
  }) {
    callCount++;
    throw StateError('The screenshot fixture must not call the API.');
  }
}
