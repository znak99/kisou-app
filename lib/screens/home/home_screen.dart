import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/home.dart';
import '../../models/recommendation.dart';
import '../../models/user.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/shell_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/error_state.dart';
import '../../widgets/feeling_headline.dart';
import '../../widgets/recommendation_card.dart';
import '../../widgets/today_weather_detail.dart';
import '../../widgets/weather_comparison.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(userProvider.notifier).getMe();
      } catch (_) {
        // Home can still render recommendations even if profile loading fails.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final user = ref
        .watch(userProvider)
        .when(
          data: (value) => value,
          error: (_, _) => null,
          loading: () => null,
        );
    return homeState.when(
      data: (home) => _HomeContent(home: home, user: user),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _HomeError(error: error),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.home, required this.user});

  final HomeResponse home;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = [...home.recommendations]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final primary = recommendations.isNotEmpty ? recommendations.first : null;
    final secondary = recommendations.skip(1).take(2).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(homeProvider.notifier).refresh(),
          ref.read(feedbackProvider.notifier).refresh(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Greeting(user: user),
          const SizedBox(height: KisouTheme.gapL),
          // 1. Clothing recommendations (rank 2/3 foldable)
          _RecommendationSection(primary: primary, secondary: secondary),
          const SizedBox(height: KisouTheme.gapL),
          // 2. Predicted feeling
          FeelingHeadline(feeling: home.feeling, nickname: user?.nickname),
          const SizedBox(height: KisouTheme.gapL),
          // 3. Today's weather
          TodayWeatherDetail(today: home.weatherComparison.today),
          const SizedBox(height: KisouTheme.gapM),
          // 4. Weather comparison
          WeatherComparison(comparison: home.weatherComparison),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final nickname = user?.nickname.trim() ?? '';
    final regionName = user?.regionName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nickname.isEmpty
              ? AppStrings.todayClothing
              : AppStrings.greetingWithNickname(nickname),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (regionName != null && regionName.isNotEmpty) ...[
          const SizedBox(height: KisouTheme.gapS),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.kisou.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: context.kisou.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 16,
                  color: KisouTheme.accent,
                ),
                const SizedBox(width: KisouTheme.gapXs),
                Text(
                  regionName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.kisou.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeError extends ConsumerWidget {
  const _HomeError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorKind = classifyApiError(error);
    final isLocationMissing = errorKind == ApiErrorKind.locationMissing;
    final message = apiErrorMessage(error);
    return RefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          ErrorState(
            message: message,
            actionLabel: isLocationMissing
                ? AppStrings.openSettings
                : AppStrings.retry,
            onAction: isLocationMissing
                ? () => ref
                      .read(shellTabProvider.notifier)
                      .setTab(ShellTab.profile)
                : () => ref.read(homeProvider.notifier).retry(),
          ),
        ],
      ),
    );
  }
}

/// Clothing recommendations: the top pick is always shown; the "warmer /
/// lighter" alternatives fold behind a "more" toggle at the bottom-right.
class _RecommendationSection extends StatefulWidget {
  const _RecommendationSection({
    required this.primary,
    required this.secondary,
  });

  final RecommendationItem? primary;
  final List<RecommendationItem> secondary;

  @override
  State<_RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<_RecommendationSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final secondary = widget.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.recommendationSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: KisouTheme.gapM),
        if (primary != null)
          RecommendationCard(
            recommendation: primary,
            size: RecommendationCardSize.large,
          ),
        if (secondary.length >= 2) ...[
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: KisouTheme.gapM),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: RecommendationCard(
                              recommendation: secondary[0],
                            ),
                          ),
                          const SizedBox(width: KisouTheme.gapM),
                          Expanded(
                            child: RecommendationCard(
                              recommendation: secondary[1],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(
                _expanded ? AppStrings.recShowLess : AppStrings.recShowMore,
              ),
            ),
          ),
        ] else
          for (final item in secondary) ...[
            const SizedBox(height: KisouTheme.gapM),
            RecommendationCard(recommendation: item),
          ],
      ],
    );
  }
}
