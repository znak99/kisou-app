import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/forecast.dart';
import '../../models/location.dart';
import '../../models/outlook_quota.dart';
import '../../providers/ad_reward_provider.dart';
import '../../providers/ads_provider.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/outlook_quota_provider.dart';
import '../../utils/jp_date.dart';
import '../../widgets/recommendation_card.dart';
import '../../widgets/weather_data_attribution.dart';
import 'travel_plans_screen.dart';

const _freeLookupsPerDay = 3;

/// Full-page "日付で予想する": pick a future date and city, get an outfit
/// estimate (real forecast when near, past-years average when far).
///
/// Reached from the 予報 tab's toolbar. The [_lookup] call is deliberately the
/// single funnel for running an estimate. Reward ads grant a server-side
/// credit, but never trigger this method automatically.
class OutlookScreen extends ConsumerStatefulWidget {
  const OutlookScreen({super.key});

  @override
  ConsumerState<OutlookScreen> createState() => _OutlookScreenState();
}

class _OutlookScreenState extends ConsumerState<OutlookScreen> {
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();

  DateTime? _date;
  LocationValue _city = majorCities.first;

  int _fixtureRemaining = _freeLookupsPerDay;

  bool _isLookupInFlight = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (ApiConfig.outlookScreenshotFixtureEnabled) {
      _date = jstToday().add(const Duration(days: 8));
    }
  }

  Future<void> _pickDate() async {
    final tomorrow = jstToday().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 329)),
    );
    if (picked != null && mounted && picked != _date) {
      ref.read(forecastOutlookProvider.notifier).resetPendingOperation();
      setState(() => _date = picked);
    }
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<LocationValue>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return ListView(
          children: [
            for (final city in majorCities)
              ListTile(
                title: Text(city.regionName),
                selected: city.regionName == _city.regionName,
                trailing: city.regionName == _city.regionName
                    ? Icon(
                        Icons.check_rounded,
                        color: sheetContext.kisou.accent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(city),
              ),
          ],
        );
      },
    );
    if (picked != null && mounted && picked.code != _city.code) {
      ref.read(forecastOutlookProvider.notifier).resetPendingOperation();
      setState(() => _city = picked);
    }
  }

  Future<void> _lookup() async {
    final date = _date;
    final remaining = ApiConfig.outlookScreenshotFixtureEnabled
        ? _fixtureRemaining
        : ref.read(outlookQuotaProvider).value?.totalRemaining ?? 0;
    if (date == null || remaining <= 0 || _isLookupInFlight) {
      return;
    }
    final city = _city;
    setState(() {
      _isLookupInFlight = true;
    });
    try {
      final outcome = await ref
          .read(forecastOutlookProvider.notifier)
          .lookup(
            date: formatIsoDate(date),
            cityCode: city.code!,
            cityName: city.regionName,
            latitude: city.latitude,
            longitude: city.longitude,
          );
      if (outcome.succeeded) {
        if (ApiConfig.outlookScreenshotFixtureEnabled && mounted) {
          setState(() {
            _fixtureRemaining = (_fixtureRemaining - 1).clamp(0, 99);
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final resultContext = _resultKey.currentContext;
          if (!mounted || resultContext == null) {
            return;
          }
          Scrollable.ensureVisible(
            resultContext,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        });
      } else if (mounted) {
        final error = outcome.error;
        final status = error is DioException
            ? error.response?.statusCode
            : null;
        final message = switch (status) {
          409 => AppStrings.forecastOutlookConflict,
          429 => AppStrings.forecastOutlookRateLimited,
          _ => AppStrings.forecastOutlookFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLookupInFlight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final outlookState = ref.watch(forecastOutlookProvider);
    final quotaState = ApiConfig.outlookScreenshotFixtureEnabled
        ? AsyncData(OutlookQuota.screenshotFixture(formatIsoDate(jstToday())))
        : ref.watch(outlookQuotaProvider);
    final quota = ApiConfig.outlookScreenshotFixtureEnabled
        ? OutlookQuota(
            date: formatIsoDate(jstToday()),
            freeLimit: _freeLookupsPerDay,
            freeUsed: _freeLookupsPerDay - _fixtureRemaining,
            freeRemaining: _fixtureRemaining,
            rewardCredits: 0,
            totalRemaining: _fixtureRemaining,
            resetsAt: DateTime.utc(2100),
            adsAvailable: false,
          )
        : quotaState.value;
    final adsState = ApiConfig.outlookScreenshotFixtureEnabled
        ? AdsState.initial(enabled: false)
        : ref.watch(adsProvider);
    final rewardState = ApiConfig.outlookScreenshotFixtureEnabled
        ? const RewardFlowState.idle()
        : ref.watch(adRewardProvider);
    final remaining = quota?.totalRemaining;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.ink,
        title: Text(
          AppStrings.forecastOutlookTitle,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(KisouTheme.cardPad),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(KisouTheme.rMd),
              border: Border.all(color: c.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 15,
                      color: c.accent,
                    ),
                    const SizedBox(width: KisouTheme.gapXs),
                    Expanded(
                      child: Text(
                        switch (remaining) {
                          null =>
                            quotaState.hasError
                                ? AppStrings.forecastOutlookQuotaFailed
                                : AppStrings.forecastOutlookQuotaLoading,
                          0 => AppStrings.forecastOutlookQuotaEmpty,
                          final n => AppStrings.forecastOutlookQuota(n),
                        },
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (quotaState.hasError &&
                        !ApiConfig.outlookScreenshotFixtureEnabled)
                      IconButton(
                        tooltip: AppStrings.retry,
                        onPressed: () {
                          ref.read(outlookQuotaProvider.notifier).refresh();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: KisouTheme.gapL),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useVertical =
                        usesLargeText(context) || constraints.maxWidth < 320;
                    final dateField = _PickerField(
                      label: AppStrings.forecastOutlookDateLabel,
                      value: _date == null ? null : formatJpDate(_date!),
                      onTap: _pickDate,
                    );
                    final cityField = _PickerField(
                      label: AppStrings.forecastOutlookPlaceLabel,
                      value: _city.regionName,
                      onTap: _pickCity,
                    );
                    if (useVertical) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dateField,
                          const SizedBox(height: KisouTheme.gapS),
                          cityField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: dateField),
                        const SizedBox(width: KisouTheme.gapS),
                        Expanded(child: cityField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: KisouTheme.gapM),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _date == null ||
                            (remaining ?? 0) <= 0 ||
                            _isLookupInFlight
                        ? null
                        : _lookup,
                    child: const Text(AppStrings.forecastOutlookSubmit),
                  ),
                ),
                if (quota != null &&
                    quota.totalRemaining == 0 &&
                    adsState.enabled &&
                    (quota.adsAvailable ||
                        rewardState.phase != RewardFlowPhase.idle)) ...[
                  const SizedBox(height: KisouTheme.gapM),
                  _RewardCreditAction(
                    adsState: adsState,
                    rewardState: rewardState,
                    newChallengeAvailable: quota.adsAvailable,
                    onPressed: () {
                      ref.read(adRewardProvider.notifier).earnCredit();
                    },
                  ),
                ] else if (rewardState.phase == RewardFlowPhase.credited) ...[
                  const SizedBox(height: KisouTheme.gapM),
                  Text(
                    AppStrings.forecastOutlookRewardCredited,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          KeyedSubtree(
            key: _resultKey,
            child: switch (outlookState) {
              null => const _OutlookEmptyState(),
              final state => state.when(
                loading: () => const _OutlookLoadingCard(),
                error: (_, _) => _OutlookErrorCard(
                  onRetry: _isLookupInFlight ? null : _lookup,
                ),
                data: (result) => _OutlookSurface(
                  child: _OutlookResult(
                    outlook: result.outlook,
                    cityName: result.cityName,
                    onSaveTravelPlan: () => showTravelPlanEditor(
                      context: context,
                      ref: ref,
                      initialDate: DateTime.parse(result.outlook.date),
                      initialCityCode: result.cityCode,
                    ),
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _RewardCreditAction extends StatelessWidget {
  const _RewardCreditAction({
    required this.adsState,
    required this.rewardState,
    required this.newChallengeAvailable,
    required this.onPressed,
  });

  final AdsState adsState;
  final RewardFlowState rewardState;
  final bool newChallengeAvailable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final phase = rewardState.phase;
    final message = switch (phase) {
      RewardFlowPhase.loadingAd => AppStrings.forecastOutlookRewardLoadingAd,
      RewardFlowPhase.issuingChallenge =>
        AppStrings.forecastOutlookRewardIssuing,
      RewardFlowPhase.showingAd => AppStrings.forecastOutlookRewardShowing,
      RewardFlowPhase.settling => AppStrings.forecastOutlookRewardSettling,
      RewardFlowPhase.delayed => AppStrings.forecastOutlookRewardDelayed,
      RewardFlowPhase.dismissed => AppStrings.forecastOutlookRewardDismissed,
      RewardFlowPhase.failed => AppStrings.forecastOutlookRewardFailed,
      RewardFlowPhase.credited => AppStrings.forecastOutlookRewardCredited,
      RewardFlowPhase.idle =>
        !adsState.mayLoadAds
            ? AppStrings.forecastOutlookRewardUnavailable
            : null,
    };
    final canStart =
        newChallengeAvailable &&
        adsState.mayLoadAds &&
        rewardState.canRequestNewChallenge;
    final buttonLabel = switch (phase) {
      RewardFlowPhase.loadingAd => AppStrings.forecastOutlookRewardLoadingAd,
      RewardFlowPhase.issuingChallenge =>
        AppStrings.forecastOutlookRewardIssuing,
      RewardFlowPhase.showingAd => AppStrings.forecastOutlookRewardShowing,
      RewardFlowPhase.settling => AppStrings.forecastOutlookRewardSettling,
      _ => AppStrings.forecastOutlookRewardAction,
    };

    return Semantics(
      container: true,
      liveRegion: phase != RewardFlowPhase.idle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(KisouTheme.gapM),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(KisouTheme.rSm),
          border: Border.all(color: c.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              onPressed: canStart ? onPressed : null,
              icon: rewardState.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ondemand_video_outlined),
              label: Text(buttonLabel, textAlign: TextAlign.center),
            ),
            if (message != null) ...[
              const SizedBox(height: KisouTheme.gapS),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.softInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutlookEmptyState extends StatelessWidget {
  const _OutlookEmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label:
          '${AppStrings.forecastOutlookEmptyTitle}。'
          '${AppStrings.forecastOutlookEmptyBody}',
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 144,
                    maxHeight: 120,
                  ),
                  child: Image.asset(
                    'assets/illustrations/outlook_empty_state.png',
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.forecastOutlookEmptyTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.forecastOutlookEmptyBody,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.kisou.softInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlookSurface extends StatelessWidget {
  const _OutlookSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Container(
      padding: const EdgeInsets.all(KisouTheme.cardPad),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(KisouTheme.rMd),
        border: Border.all(color: c.hairline),
      ),
      child: child,
    );
  }
}

class _OutlookLoadingCard extends StatelessWidget {
  const _OutlookLoadingCard();

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: AppStrings.forecastOutlookLoading,
      child: ExcludeSemantics(
        child: _OutlookSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: bar(double.infinity, 16)),
                  const SizedBox(width: KisouTheme.gapL),
                  bar(72, 20),
                ],
              ),
              const SizedBox(height: KisouTheme.gapM),
              bar(190, 22),
              const SizedBox(height: KisouTheme.gapL),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(KisouTheme.rMd),
                ),
              ),
              const SizedBox(height: KisouTheme.gapM),
              bar(double.infinity, 14),
              const SizedBox(height: KisouTheme.gapS),
              bar(220, 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlookErrorCard extends StatelessWidget {
  const _OutlookErrorCard({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: _OutlookSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: KisouTheme.gapM),
            Text(
              AppStrings.forecastOutlookFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: KisouTheme.gapM),
            FilledButton(
              onPressed: onRetry,
              child: const Text(AppStrings.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final displayValue = value ?? '--';
    return Semantics(
      button: true,
      label: label,
      value: displayValue,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KisouTheme.rSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KisouTheme.rSm),
                border: Border.all(color: c.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.softInk,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayValue,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value == null ? c.softInk : c.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlookResult extends StatelessWidget {
  const _OutlookResult({
    required this.outlook,
    required this.cityName,
    required this.onSaveTravelPlan,
  });

  final ForecastOutlook outlook;
  final String cityName;
  final VoidCallback onSaveTravelPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.parse(outlook.date);
    final climate = outlook.climate;
    final weather = outlook.weather;

    // Headline range: climatology shows past-years AVERAGES (平年値-style,
    // per review — extremes would read alarmingly wide); forecast shows the
    // forecast day's low/high.
    String? headline;
    if (outlook.isClimatology && climate != null) {
      headline = AppStrings.forecastClimateRange(
        climate.tempLowAvg.round().toString(),
        climate.tempHighAvg.round().toString(),
      );
    } else if (weather != null &&
        weather.tempLow != null &&
        weather.tempHigh != null) {
      headline = '${weather.tempLow!.round()}°〜${weather.tempHigh!.round()}°';
    }

    final recommendations = [...outlook.recommendations]
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ApiConfig.outlookScreenshotFixtureEnabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KisouTheme.gapS,
              vertical: KisouTheme.gapXs,
            ),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.1),
              border: Border.all(color: c.accent.withValues(alpha: 0.28)),
              borderRadius: BorderRadius.circular(KisouTheme.rSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 16, color: c.accent),
                const SizedBox(width: KisouTheme.gapXs),
                Flexible(
                  child: Text(
                    AppStrings.forecastOutlookScreenshotNotice,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KisouTheme.gapS),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final useVertical =
                usesLargeText(context) || constraints.maxWidth < 300;
            final dateText = Text(
              '$cityName・${formatJpDate(date)}',
              style: textTheme.bodySmall?.copyWith(
                color: c.softInk,
                fontWeight: FontWeight.w600,
              ),
            );
            final headlineText = headline == null
                ? null
                : Text(
                    headline,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
            if (useVertical) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dateText,
                  if (headlineText != null) ...[
                    const SizedBox(height: KisouTheme.gapXs),
                    headlineText,
                  ],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: dateText),
                if (headlineText != null) ...[
                  const SizedBox(width: KisouTheme.gapM),
                  headlineText,
                ],
              ],
            );
          },
        ),
        // Personalized felt-temperature line: the estimate runs through the
        // same comfort engine as home, offset included (review 15).
        const SizedBox(height: KisouTheme.gapS),
        Text(
          AppStrings.forecastFeelingLine(outlook.feeling),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: KisouTheme.gapM),
          RecommendationCard(
            recommendation: recommendations.first,
            size: RecommendationCardSize.large,
          ),
        ],
        // How the estimate was made — data source template (review 15).
        const SizedBox(height: KisouTheme.gapS),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 13, color: c.softInk),
            const SizedBox(width: KisouTheme.gapXs),
            Expanded(
              child: Text(
                ApiConfig.outlookScreenshotFixtureEnabled
                    ? AppStrings.forecastOutlookScreenshotSource
                    : outlook.isClimatology && climate != null
                    ? AppStrings.forecastExplainClimatology(
                        years: climate.yearsUsed,
                        sampleDays: climate.sampleDays,
                        low: climate.tempLowAvg.round().toString(),
                        high: climate.tempHighAvg.round().toString(),
                      )
                    : AppStrings.forecastExplainForecastMode,
                style: textTheme.bodySmall?.copyWith(
                  color: c.softInk,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: KisouTheme.gapXs),
        const WeatherDataAttribution(),
        const SizedBox(height: KisouTheme.gapM),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSaveTravelPlan,
            icon: const Icon(Icons.luggage_outlined),
            label: const Text(AppStrings.travelSaveFromOutlook),
          ),
        ),
      ],
    );
  }
}
