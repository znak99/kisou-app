import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/home.dart';
import '../../models/user.dart';
import '../../providers/home_provider.dart';
import '../../providers/user_provider.dart';
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
      body: homeState.when(
        data: (home) => _HomeContent(home: home, user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HomeError(error: error),
      ),
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
      onRefresh: () => ref.read(homeProvider.notifier).refresh(),
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
