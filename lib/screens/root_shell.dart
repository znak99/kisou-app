import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/feedback_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/home_provider.dart';
import '../providers/shell_provider.dart';
import '../utils/jp_date.dart';
import '../widgets/ad_slot.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/feedback_action_button.dart';
import '../widgets/kisou_top_bar.dart';
import '../widgets/outlook_action_button.dart';
import 'forecast/forecast_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

/// Root scaffold after login/onboarding: three tabs behind a persistent
/// bottom navigation. The unfinished ad placeholder is development-only.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  static const _tabs = [HomeScreen(), ForecastScreen(), ProfileScreen()];

  // Only tabs the user has actually opened are built; others stay as an empty
  // placeholder so their providers don't fire on startup (audit B23). Once
  // visited a tab is kept alive (IndexedStack preserves its state).
  final Set<int> _visitedTabs = {ShellTab.home};

  // "Today" (JST) drives the feedback button, home and tomorrow data. When
  // the JST date rolls over — at midnight while the app is open, or while it
  // was backgrounded — everything keyed on today must reload (review 11).
  Timer? _midnightTimer;
  DateTime _lastSeenDay = jstToday();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRollover();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rolloverIfNewDay();
    }
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(
      // +1s so the timer never lands a hair BEFORE midnight.
      durationUntilNextJstDay(DateTime.now()) + const Duration(seconds: 1),
      _rolloverIfNewDay,
    );
  }

  void _rolloverIfNewDay() {
    if (!mounted) {
      return;
    }
    final today = jstToday();
    if (today != _lastSeenDay) {
      _lastSeenDay = today;
      // A new JST day: yesterday's feedback no longer counts as "done", the
      // recommendation is for a new day, and tomorrow moved.
      ref.invalidate(feedbackProvider);
      ref.invalidate(homeProvider);
      ref.invalidate(forecastTomorrowProvider);
    }
    _scheduleMidnightRollover();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);
    _visitedTabs.add(index);
    return Scaffold(
      backgroundColor: context.kisou.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            KisouTopBar(
              action: switch (index) {
                ShellTab.home => const FeedbackActionButton(),
                ShellTab.forecast => const OutlookActionButton(),
                _ => null,
              },
            ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _visitedTabs.contains(i)
                        ? _tabs[i]
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ApiConfig.developmentFeaturesEnabled) const AdSlot(),
          SafeArea(
            top: false,
            child: AppBottomNav(
              currentIndex: index,
              onTap: (value) =>
                  ref.read(shellTabProvider.notifier).setTab(value),
            ),
          ),
        ],
      ),
    );
  }
}
