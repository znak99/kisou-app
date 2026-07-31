import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/providers/ad_reward_provider.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/providers/outlook_quota_provider.dart';
import 'package:kisou_app/screens/forecast/outlook_screen.dart';

void main() {
  testWidgets('reward CTA appears only when authoritative quota is exhausted', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_quota(remaining: 0, adsAvailable: true)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.forecastOutlookRewardAction), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(_quota(remaining: 1, adsAvailable: true)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.forecastOutlookRewardAction), findsNothing);
  });

  testWidgets('settlement notice remains when server blocks new challenges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _quota(remaining: 0, adsAvailable: false),
        rewardState: RewardFlowState(
          phase: RewardFlowPhase.delayed,
          settlementExpiresAt: DateTime.utc(2026, 8, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.forecastOutlookRewardDelayed), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.forecastOutlookRewardAction),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'credited state enables the next grant after credit consumption',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _quota(remaining: 0, adsAvailable: true),
          rewardState: RewardFlowState(
            phase: RewardFlowPhase.credited,
            settlementExpiresAt: DateTime.utc(2026, 8, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.forecastOutlookRewardCredited),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          AppStrings.forecastOutlookRewardAction,
        ),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('reward states fit 320dp at 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        _quota(remaining: 0, adsAvailable: false),
        rewardState: RewardFlowState(
          phase: RewardFlowPhase.delayed,
          settlementExpiresAt: DateTime.utc(2026, 8, 1),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.forecastOutlookRewardDelayed), findsOneWidget);
  });
}

Widget _app(
  OutlookQuota quota, {
  RewardFlowState rewardState = const RewardFlowState.idle(),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      outlookQuotaProvider.overrideWith(() => _FixedQuotaController(quota)),
      adsProvider.overrideWith(_ReadyAdsController.new),
      adRewardProvider.overrideWith(() => _FixedRewardController(rewardState)),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: const OutlookScreen(),
      ),
    ),
  );
}

class _FixedQuotaController extends OutlookQuotaController {
  _FixedQuotaController(this.quota);

  final OutlookQuota quota;

  @override
  Future<OutlookQuota> build() async => quota;
}

class _ReadyAdsController extends AdsController {
  @override
  AdsState build() {
    return const AdsState(
      enabled: true,
      consentInProgress: false,
      canRequestAds: true,
      sdkInitialized: true,
      privacyOptionsRequired: false,
      generation: 1,
    );
  }
}

class _FixedRewardController extends AdRewardController {
  _FixedRewardController(this.initial);

  final RewardFlowState initial;

  @override
  RewardFlowState build() => initial;
}

OutlookQuota _quota({required int remaining, required bool adsAvailable}) {
  return OutlookQuota(
    date: '2026-07-31',
    freeLimit: 3,
    freeUsed: 3 - remaining,
    freeRemaining: remaining,
    rewardCredits: 0,
    totalRemaining: remaining,
    resetsAt: DateTime.utc(2026, 7, 31, 15),
    adsAvailable: adsAvailable,
  );
}
