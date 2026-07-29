import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/forecast.dart';
import '../../models/location.dart';
import '../../providers/forecast_provider.dart';
import '../../utils/jp_date.dart';
import '../../widgets/recommendation_card.dart';

/// Free lookups per day (JST). The rewarded-ad "+1" is planned but not wired
/// yet, so the intro copy marks it 準備中.
const _freeLookupsPerDay = 3;
const _quotaDateKey = 'outlook_quota_date';
const _quotaUsedKey = 'outlook_quota_used';

/// Full-page "日付で予想する": pick a future date and city, get an outfit
/// estimate (real forecast when near, past-years average when far).
///
/// Reached from the 予報 tab's toolbar. The [_lookup] call is deliberately the
/// single funnel for running an estimate — a future rewarded-ad gate ("watch
/// an ad for one lookup") wraps that one method and nothing else.
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

  /// Lookups left today. Null while loading from storage.
  int? _remaining;

  /// City shown with the current result (captured when 予想する is pressed, so
  /// changing the picker afterwards doesn't relabel an old result).
  LocationValue? _lookedUpCity;

  bool _isLookupInFlight = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = formatIsoDate(jstToday());
    final used = prefs.getString(_quotaDateKey) == today
        ? (prefs.getInt(_quotaUsedKey) ?? 0)
        : 0; // 날짜가 바뀌면 리셋.
    if (mounted) {
      setState(() => _remaining = (_freeLookupsPerDay - used).clamp(0, 99));
    }
  }

  Future<void> _consumeQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = formatIsoDate(jstToday());
    final used = prefs.getString(_quotaDateKey) == today
        ? (prefs.getInt(_quotaUsedKey) ?? 0)
        : 0;
    await prefs.setString(_quotaDateKey, today);
    await prefs.setInt(_quotaUsedKey, used + 1);
    if (mounted) {
      setState(() {
        _remaining = (_freeLookupsPerDay - used - 1).clamp(0, 99);
      });
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
    if (picked != null && mounted) {
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
    if (picked != null && mounted) {
      setState(() => _city = picked);
    }
  }

  Future<void> _lookup() async {
    final date = _date;
    if (date == null || (_remaining ?? 0) <= 0 || _isLookupInFlight) {
      return;
    }
    final city = _city;
    setState(() {
      _isLookupInFlight = true;
      _lookedUpCity = city;
    });
    try {
      final succeeded = await ref
          .read(forecastOutlookProvider.notifier)
          .lookup(
            date: formatIsoDate(date),
            latitude: city.latitude,
            longitude: city.longitude,
          );
      // Only a successful estimate consumes the daily count — failures retry
      // for free.
      if (succeeded) {
        await _consumeQuota();
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
                        switch (_remaining) {
                          null => '',
                          0 => AppStrings.forecastOutlookQuotaEmpty,
                          final n => AppStrings.forecastOutlookQuota(n),
                        },
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 21),
                  child: Text(
                    AppStrings.forecastOutlookAdNote,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.softInk,
                      fontSize: 11,
                    ),
                  ),
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
                            (_remaining ?? 0) <= 0 ||
                            _isLookupInFlight
                        ? null
                        : _lookup,
                    child: const Text(AppStrings.forecastOutlookSubmit),
                  ),
                ),
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
                data: (outlook) => _OutlookSurface(
                  child: _OutlookResult(
                    outlook: outlook,
                    cityName: _lookedUpCity?.regionName ?? _city.regionName,
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
  const _OutlookResult({required this.outlook, required this.cityName});

  final ForecastOutlook outlook;
  final String cityName;

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
                outlook.isClimatology && climate != null
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
      ],
    );
  }
}
