import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/forecast.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/providers/forecast_provider.dart';
import 'package:kisou_app/screens/forecast/outlook_screen.dart';
import 'package:kisou_app/services/forecast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the approved illustrated empty state before lookup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OutlookScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.forecastOutlookEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.forecastOutlookEmptyBody), findsOneWidget);
    expect(find.text(AppStrings.forecastOutlookScreenshotNotice), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/illustrations/outlook_empty_state.png',
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.forecastOutlookIntro), findsNothing);
  });

  testWidgets('rapid taps start one lookup and consume one quota', (
    WidgetTester tester,
  ) async {
    final service = _DelayedForecastService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [forecastServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: OutlookScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.forecastOutlookDateLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final submit = find.text(AppStrings.forecastOutlookSubmit);
    await tester.tap(submit);
    await tester.tap(submit);
    expect(service.callCount, 1);

    service.complete();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.forecastOutlookQuota(2)), findsOneWidget);
    expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
    expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
    expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
  });

  testWidgets(
    'result and travel-save defaults keep the city captured by the request',
    (WidgetTester tester) async {
      final service = _DelayedForecastService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [forecastServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: OutlookScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.forecastOutlookDateLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.forecastOutlookSubmit));
      await tester.pump();

      await tester.tap(find.text(AppStrings.forecastOutlookPlaceLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('大阪'));
      await tester.pumpAndSettle();

      service.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('東京・'), findsOneWidget);
      expect(find.text('大阪'), findsOneWidget);

      await tester.tap(find.text(AppStrings.travelSaveFromOutlook));
      await tester.pumpAndSettle();

      final cityField = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(cityField.initialValue, 'tokyo');
      expect(
        find.byType(DropdownButtonFormField<TravelReminder>),
        findsOneWidget,
      );
    },
  );
}

class _DelayedForecastService extends ForecastService {
  _DelayedForecastService() : super(Dio());

  final _completer = Completer<ForecastOutlookResponse>();
  var callCount = 0;

  @override
  Future<ForecastOutlookResponse> getOutlook({
    required String date,
    required double latitude,
    required double longitude,
    required String idempotencyKey,
  }) {
    callCount++;
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      ForecastOutlookResponse(
        outlook: const ForecastOutlook(
          date: '2026-07-29',
          mode: 'forecast',
          feeling: 'PERFECT',
          comfortMin: 20,
          comfortMax: 22,
          recommendations: [],
          weather: null,
          climate: null,
        ),
        quotaConsumed: 'free',
        quota: _quota(2),
      ),
    );
  }

  @override
  Future<OutlookQuota> getOutlookQuota() async => _quota(3);
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
