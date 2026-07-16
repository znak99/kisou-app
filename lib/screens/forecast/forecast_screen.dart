import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/feedback.dart';
import '../../models/forecast.dart';
import '../../models/location.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/recommendation_card.dart';

const _weekdayJp = ['月', '火', '水', '木', '金', '土', '日'];

String _formatJpDate(DateTime date) {
  return '${date.month}/${date.day}（${_weekdayJp[date.weekday - 1]}）';
}

/// 予報 tab: tomorrow's outfit, a feedback nudge, and a date/place lookup.
class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          AppStrings.forecastTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: KisouTheme.gapL),
        const _TomorrowCard(),
        const SizedBox(height: KisouTheme.gapM),
        const _FeedbackNudge(),
        const SizedBox(height: KisouTheme.gapL),
        const _OutlookSection(),
      ],
    );
  }
}

Widget _card(BuildContext context, {required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(KisouTheme.cardPad),
    decoration: BoxDecoration(
      color: context.kisou.surface,
      borderRadius: BorderRadius.circular(KisouTheme.rMd),
      border: Border.all(color: context.kisou.hairline),
    ),
    child: child,
  );
}

// --- 1. Tomorrow ------------------------------------------------------------

class _TomorrowCard extends ConsumerWidget {
  const _TomorrowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(forecastTomorrowProvider);
    return state.when(
      data: (forecast) => _TomorrowContent(forecast: forecast),
      loading: () => _card(
        context,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(KisouTheme.gapL),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              apiErrorMessage(error),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: KisouTheme.gapS),
            TextButton(
              onPressed: () {
                ref.read(forecastTomorrowProvider.notifier).retry();
              },
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _TomorrowContent extends StatelessWidget {
  const _TomorrowContent({required this.forecast});

  final ForecastTomorrow forecast;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.parse(forecast.date);
    final low = forecast.weather.tempLow;
    final high = forecast.weather.tempHigh;
    final todayHigh = forecast.todayWeather.tempHigh;
    final rain = forecast.weather.precipitationChanceMax;

    String? comparison;
    if (high != null && todayHigh != null) {
      final diff = (high - todayHigh).round();
      comparison = diff == 0
          ? AppStrings.forecastSameAsToday
          : AppStrings.forecastComparedToToday(diff);
    }

    final recommendations = [...forecast.recommendations]
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_twilight_rounded,
                size: 16,
                color: KisouTheme.accent,
              ),
              const SizedBox(width: KisouTheme.gapXs),
              Text(
                '${AppStrings.forecastTomorrowLabel} ${_formatJpDate(date)}',
                style: textTheme.bodySmall?.copyWith(
                  color: c.softInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (low != null && high != null)
                Text(
                  '${low.round()}° / ${high.round()}°',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (comparison != null) ...[
            const SizedBox(height: KisouTheme.gapM),
            Text(
              comparison,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (rain != null) ...[
            const SizedBox(height: KisouTheme.gapXs),
            Text(
              '${AppStrings.weatherPrecipitation} $rain%',
              style: textTheme.bodySmall?.copyWith(color: c.softInk),
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: KisouTheme.gapM),
            RecommendationCard(recommendation: recommendations.first),
          ],
        ],
      ),
    );
  }
}

// --- 2. Feedback nudge -------------------------------------------------------

class _FeedbackNudge extends ConsumerWidget {
  const _FeedbackNudge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackState = ref.watch(feedbackProvider);
    return feedbackState.when(
      // The nudge is a bonus entry point, not core content: while unknown
      // (loading/error) it just stays out of the way.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        final submitted = status.exists && status.feedback != null;
        final c = context.kisou;
        final textTheme = Theme.of(context).textTheme;
        if (submitted) {
          return _card(
            context,
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: KisouTheme.accent,
                ),
                const SizedBox(width: KisouTheme.gapS),
                Text(
                  AppStrings.forecastNudgeDone,
                  style: textTheme.bodyMedium?.copyWith(
                    color: c.softInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return _card(
          context,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.forecastNudgeTitle,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.forecastNudgeBody,
                      style: textTheme.bodySmall?.copyWith(color: c.softInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KisouTheme.gapS),
              TextButton(
                onPressed: () => _openSheet(context, ref, status.feedback),
                child: const Text(AppStrings.forecastNudgeAction),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    FeedbackResponse? initialFeedback,
  ) async {
    final user = ref
        .read(userProvider)
        .when(
          data: (value) => value,
          error: (_, _) => null,
          loading: () => null,
        );
    final submitted = await showFeedbackSheet(
      context: context,
      gender: user?.gender,
      initialFeedback: initialFeedback,
    );
    if (submitted == true) {
      // Same follow-up as the home entry point, plus tomorrow's card (visible
      // right here) because the offset shift changes its recommendation.
      await Future.wait([
        ref.read(homeProvider.notifier).refresh(),
        ref.read(userProvider.notifier).getMe(),
        ref.read(forecastTomorrowProvider.notifier).refresh(),
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedbackApplied)),
        );
      }
    }
  }
}

// --- 3. Date/place lookup ----------------------------------------------------

class _OutlookSection extends ConsumerStatefulWidget {
  const _OutlookSection();

  @override
  ConsumerState<_OutlookSection> createState() => _OutlookSectionState();
}

class _OutlookSectionState extends ConsumerState<_OutlookSection> {
  DateTime? _date;
  LocationValue _city = majorCities.first;

  /// City shown with the current result (captured when 予想する is pressed, so
  /// changing the picker afterwards doesn't relabel an old result).
  LocationValue? _lookedUpCity;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 329)),
    );
    if (picked != null) {
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
                trailing: city.regionName == _city.regionName
                    ? const Icon(
                        Icons.check_rounded,
                        color: KisouTheme.accent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(city),
              ),
          ],
        );
      },
    );
    if (picked != null) {
      setState(() => _city = picked);
    }
  }

  void _lookup() {
    final date = _date;
    if (date == null) {
      return;
    }
    _lookedUpCity = _city;
    final formatted =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    ref
        .read(forecastOutlookProvider.notifier)
        .lookup(
          date: formatted,
          latitude: _city.latitude,
          longitude: _city.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final outlookState = ref.watch(forecastOutlookProvider);

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: KisouTheme.accent,
              ),
              const SizedBox(width: KisouTheme.gapS),
              Text(
                AppStrings.forecastOutlookTitle,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: KisouTheme.gapM),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: AppStrings.forecastOutlookDateLabel,
                  value: _date == null ? null : _formatJpDate(_date!),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: KisouTheme.gapS),
              Expanded(
                child: _PickerField(
                  label: AppStrings.forecastOutlookPlaceLabel,
                  value: _city.regionName,
                  onTap: _pickCity,
                ),
              ),
            ],
          ),
          const SizedBox(height: KisouTheme.gapM),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _date == null ? null : _lookup,
              child: const Text(AppStrings.forecastOutlookSubmit),
            ),
          ),
          if (outlookState != null) ...[
            const SizedBox(height: KisouTheme.gapM),
            Divider(height: 1, color: c.hairline),
            const SizedBox(height: KisouTheme.gapM),
            outlookState.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(KisouTheme.gapS),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Text(
                AppStrings.forecastOutlookFailed,
                style: textTheme.bodySmall?.copyWith(color: c.softInk),
              ),
              data: (outlook) => _OutlookResult(
                outlook: outlook,
                cityName: _lookedUpCity?.regionName ?? _city.regionName,
              ),
            ),
          ],
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KisouTheme.rSm),
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
              value ?? '--',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: value == null ? c.softInk : c.ink,
              ),
            ),
          ],
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
        Row(
          children: [
            Text(
              '$cityName・${_formatJpDate(date)}',
              style: textTheme.bodySmall?.copyWith(
                color: c.softInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (headline != null)
              Text(
                headline,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: KisouTheme.gapM),
          RecommendationCard(recommendation: recommendations.first),
        ],
        if (outlook.isClimatology && climate != null) ...[
          const SizedBox(height: KisouTheme.gapS),
          Text(
            AppStrings.forecastClimateSource(climate.yearsUsed),
            style: textTheme.bodySmall?.copyWith(
              color: c.softInk,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
