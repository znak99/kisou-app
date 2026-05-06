import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/feedback.dart';
import '../../models/home.dart';
import '../../models/user.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/recommendation_card.dart';
import '../../widgets/weather_comparison.dart';
import '../settings/settings_screen.dart';

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
    debugPrint('Feedback state: ${_describeFeedbackState(feedbackState)}');
    final user = ref
        .watch(userProvider)
        .when(
          data: (value) => value,
          error: (_, _) => null,
          loading: () => null,
        );
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: AppStrings.settings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      bottomNavigationBar: homeState.maybeWhen(
        data: (_) =>
            _FeedbackBottomBar(user: user, feedbackState: feedbackState),
        orElse: () => null,
      ),
      body: homeState.when(
        data: (home) => _HomeContent(home: home, user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HomeError(error: error),
      ),
    );
  }

  String _describeFeedbackState(AsyncValue<FeedbackTodayResponse> state) {
    return state.when(
      data: (value) =>
          'data(exists=${value.exists}, hasFeedback=${value.feedback != null})',
      error: (error, _) => 'error($error)',
      loading: () => 'loading',
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _Greeting(user: user),
          const SizedBox(height: 20),
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
        ],
      ),
    );
  }
}

class _FeedbackBottomBar extends ConsumerWidget {
  const _FeedbackBottomBar({required this.user, required this.feedbackState});

  final User? user;
  final AsyncValue<FeedbackTodayResponse> feedbackState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
              error: (_, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.dataFetchFailed,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(feedbackProvider.notifier).refresh(),
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
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
          const SizedBox(height: 8),
          Text(
            '📍 $regionName',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KisouTheme.softInk),
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
    final message = _isLocationMissingError(error)
        ? AppStrings.locationNotConfigured
        : AppStrings.dataFetchFailed;
    return RefreshIndicator(
      onRefresh: () => ref.read(homeProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          Icon(
            Icons.cloud_off,
            size: 44,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(homeProvider.notifier).retry(),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  bool _isLocationMissingError(Object error) {
    if (error is! DioException) {
      return false;
    }
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final text = data.toString().toLowerCase();
    return statusCode == 400 ||
        text.contains('location') ||
        text.contains('latitude') ||
        text.contains('longitude');
  }
}
