import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/feedback.dart';
import '../../models/home.dart';
import '../../models/user.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/shell_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/error_state.dart';
import '../../widgets/feeling_headline.dart';
import '../../widgets/feedback_sheet.dart';
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
    final feedbackState = ref.watch(feedbackProvider);
    final user = ref
        .watch(userProvider)
        .when(
          data: (value) => value,
          error: (_, _) => null,
          loading: () => null,
        );
    return SafeArea(
      bottom: false,
      child: homeState.when(
        data: (home) => _HomeContent(
          home: home,
          user: user,
          feedbackState: feedbackState,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HomeError(error: error),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.home,
    required this.user,
    required this.feedbackState,
  });

  final HomeResponse home;
  final User? user;
  final AsyncValue<FeedbackTodayResponse> feedbackState;

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const BrandLogo(variant: BrandLogoVariant.lockup, size: 30),
          const SizedBox(height: 18),
          _Greeting(user: user),
          const SizedBox(height: 16),
          FeelingHeadline(feeling: home.feeling),
          const SizedBox(height: 16),
          TodayWeatherDetail(today: home.weatherComparison.today),
          const SizedBox(height: 24),
          Text(
            AppStrings.recommendationSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (primary != null)
            RecommendationCard(
              recommendation: primary,
              size: RecommendationCardSize.large,
            ),
          for (final item in secondary) ...[
            const SizedBox(height: 12),
            RecommendationCard(recommendation: item),
          ],
          const SizedBox(height: 20),
          WeatherComparison(comparison: home.weatherComparison),
          const SizedBox(height: 20),
          _FeedbackCard(user: user, feedbackState: feedbackState),
        ],
      ),
    );
  }
}

class _FeedbackCard extends ConsumerWidget {
  const _FeedbackCard({required this.user, required this.feedbackState});

  final User? user;
  final AsyncValue<FeedbackTodayResponse> feedbackState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClayCard(
      padding: const EdgeInsets.all(18),
      child: feedbackState.when(
        data: (status) {
          final feedback = status.feedback;
          if (status.exists && feedback != null) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.feedbackDone,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => _openFeedbackSheet(
                    context: context,
                    ref: ref,
                    user: user,
                    initialFeedback: feedback,
                  ),
                  child: const Text(AppStrings.feedbackChange),
                ),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.feedbackPrompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _openFeedbackSheet(
                  context: context,
                  ref: ref,
                  user: user,
                  initialFeedback: null,
                ),
                child: const Text(AppStrings.feedbackButton),
              ),
            ],
          );
        },
        error: (error, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              apiErrorMessage(error),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(feedbackProvider.notifier).refresh(),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _openFeedbackSheet({
    required BuildContext context,
    required WidgetRef ref,
    required User? user,
    required FeedbackResponse? initialFeedback,
  }) async {
    final submitted = await showFeedbackSheet(
      context: context,
      gender: user?.gender,
      initialFeedback: initialFeedback,
    );
    if (submitted == true) {
      await Future.wait([
        ref.read(homeProvider.notifier).refresh(),
        ref.read(userProvider.notifier).getMe(),
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedbackApplied)),
        );
      }
    }
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
              : '$nicknameさん、${AppStrings.todayClothing}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (regionName != null && regionName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: KisouTheme.surface,
              borderRadius: BorderRadius.circular(100),
              boxShadow: KisouTheme.tileShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 16,
                  color: KisouTheme.deepSky,
                ),
                const SizedBox(width: 5),
                Text(
                  regionName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KisouTheme.ink,
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
