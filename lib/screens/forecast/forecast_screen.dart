import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/feedback.dart';
import '../../models/forecast.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_error.dart';
import '../../utils/jp_date.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/recommendation_card.dart';

/// 予報 tab: tomorrow's outfit and a feedback nudge. The date/place lookup
/// lives on its own page ([OutlookScreen]), reached from the tab's toolbar.
class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _TomorrowCard(),
        SizedBox(height: KisouTheme.gapM),
        _FeedbackNudge(),
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
                '${AppStrings.forecastTomorrowLabel} ${formatJpDate(date)}',
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
            // Same visual weight as the home tab's primary recommendation
            // (review: the small card's clothing icons read too small here).
            RecommendationCard(
              recommendation: recommendations.first,
              size: RecommendationCardSize.large,
            ),
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
