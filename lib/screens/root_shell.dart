import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../models/push_notification.dart';
import '../providers/ad_reward_provider.dart';
import '../providers/ads_provider.dart';
import '../providers/feedback_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/home_provider.dart';
import '../providers/outlook_quota_provider.dart';
import '../providers/push_provider.dart';
import '../providers/shell_provider.dart';
import '../providers/travel_plan_provider.dart';
import '../utils/jp_date.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/feedback_action_button.dart';
import '../widgets/kisou_top_bar.dart';
import '../widgets/outlook_action_button.dart';
import 'forecast/forecast_screen.dart';
import 'forecast/travel_plans_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

/// Root scaffold after login/onboarding: three tabs behind a persistent
/// bottom navigation.
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
  bool _openingTravelPlan = false;
  bool _handlingPushNavigation = false;
  String? _shownForegroundDeliveryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRollover();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileTravelPlans();
      _openQueuedTravelPlan();
    });
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
      if (ref.exists(adsProvider)) {
        unawaited(
          ref
              .read(adsProvider.notifier)
              .retryInitialization()
              .catchError((_) {}),
        );
      }
      final rolledOver = _rolloverIfNewDay();
      if (!rolledOver) {
        _reconcileTravelPlans();
      }
      if (ref.exists(adRewardProvider)) {
        unawaited(
          ref
              .read(adRewardProvider.notifier)
              .refreshAfterResume()
              .catchError((_) {}),
        );
      } else if (ref.exists(outlookQuotaProvider)) {
        unawaited(
          ref.read(outlookQuotaProvider.notifier).refresh().catchError((_) {}),
        );
      }
      if (ref.exists(pushSettingsProvider)) {
        final pushState = ref.read(pushSettingsProvider).value;
        unawaited(
          (pushState?.available == true
                  ? ref
                        .read(pushSettingsProvider.notifier)
                        .refreshAuthorizationAfterResume()
                  : ref.read(pushSettingsProvider.notifier).retry())
              .catchError((_) {}),
        );
      }
    } else if (ref.exists(adRewardProvider)) {
      ref.read(adRewardProvider.notifier).pausePollingForBackground();
    }
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(
      // +1s so the timer never lands a hair BEFORE midnight.
      durationUntilNextJstDay(DateTime.now()) + const Duration(seconds: 1),
      () => _rolloverIfNewDay(),
    );
  }

  bool _rolloverIfNewDay() {
    if (!mounted) {
      return false;
    }
    final today = jstToday();
    final rolledOver = today != _lastSeenDay;
    if (rolledOver) {
      _lastSeenDay = today;
      // A new JST day: yesterday's feedback no longer counts as "done", the
      // recommendation is for a new day, and tomorrow moved.
      ref.invalidate(feedbackProvider);
      ref.invalidate(homeProvider);
      ref.invalidate(forecastTomorrowProvider);
      _reconcileTravelPlans();
    }
    _scheduleMidnightRollover();
    return rolledOver;
  }

  void _reconcileTravelPlans() {
    unawaited(
      ref
          .read(travelPlanProvider.notifier)
          .refreshAndReconcile()
          .catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Starts FCM tap/token listeners for every authenticated, onboarded user;
    // opening the settings screen is never required.
    ref.watch(pushSettingsProvider);
    ref.listen<int?>(travelNotificationNavigationProvider, (_, next) {
      if (next != null) {
        _openQueuedTravelPlan();
      }
    });
    ref.listen<List<PushNotificationIntent>>(pushNavigationQueueProvider, (
      _,
      next,
    ) {
      if (next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openQueuedPushNavigation();
        });
      }
    });
    ref.listen<PushNotificationIntent?>(pushForegroundNotificationProvider, (
      _,
      next,
    ) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForegroundPush(next);
        });
      }
    });
    if (ref.read(pushNavigationQueueProvider).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openQueuedPushNavigation();
      });
    }
    final foregroundNotice = ref.read(pushForegroundNotificationProvider);
    if (foregroundNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForegroundPush(foregroundNotice);
      });
    }
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(
          currentIndex: index,
          onTap: (value) => ref.read(shellTabProvider.notifier).setTab(value),
        ),
      ),
    );
  }

  void _openQueuedTravelPlan() {
    if (!mounted || _openingTravelPlan) {
      return;
    }
    final planId = ref
        .read(travelNotificationNavigationProvider.notifier)
        .consume();
    if (planId == null) {
      return;
    }
    _openingTravelPlan = true;
    ref.read(shellTabProvider.notifier).setTab(ShellTab.forecast);
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TravelPlansScreen(focusPlanId: planId),
          ),
        )
        .whenComplete(() {
          _openingTravelPlan = false;
          _openQueuedTravelPlan();
        });
  }

  void _showForegroundPush(PushNotificationIntent intent) {
    if (!mounted || _shownForegroundDeliveryId == intent.deliveryId) {
      return;
    }
    _shownForegroundDeliveryId = intent.deliveryId;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    final title = intent.type == PushNotificationType.morningRecommendation
        ? AppStrings.pushForegroundMorningTitle
        : AppStrings.pushForegroundEveningTitle;
    final body = intent.type == PushNotificationType.morningRecommendation
        ? AppStrings.pushForegroundMorningBody
        : AppStrings.pushForegroundEveningBody;
    final controller = messenger.showMaterialBanner(
      MaterialBanner(
        forceActionsBelow: usesLargeText(context),
        leading: const Icon(Icons.notifications_active_outlined),
        content: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              unawaited(
                ref
                    .read(pushSettingsProvider.notifier)
                    .openForegroundNotification(intent.deliveryId),
              );
            },
            child: const Text(AppStrings.pushForegroundOpen),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              ref
                  .read(pushSettingsProvider.notifier)
                  .dismissForegroundNotification(intent.deliveryId);
            },
            child: const Text(AppStrings.pushForegroundDismiss),
          ),
        ],
      ),
    );
    unawaited(
      controller.closed.then((_) {
        if (_shownForegroundDeliveryId == intent.deliveryId) {
          _shownForegroundDeliveryId = null;
        }
        if (mounted && ref.exists(pushSettingsProvider)) {
          ref
              .read(pushSettingsProvider.notifier)
              .dismissForegroundNotification(intent.deliveryId);
        }
      }),
    );
  }

  void _openQueuedPushNavigation() {
    if (!mounted || _handlingPushNavigation) {
      return;
    }
    final intent = ref.read(pushNavigationQueueProvider.notifier).consume();
    if (intent == null) {
      return;
    }
    _handlingPushNavigation = true;
    unawaited(
      _performPushNavigation(intent)
          .then((opened) async {
            if (opened) {
              try {
                await ref
                    .read(pushDeliveryReceiptStoreProvider)
                    .completeNavigation(intent.deliveryId);
              } catch (_) {
                // A pending receipt is deliberately retained for crash-safe
                // recovery when completion cannot be persisted.
              }
            }
          })
          .whenComplete(() {
            _handlingPushNavigation = false;
            _openQueuedPushNavigation();
          }),
    );
  }

  Future<bool> _performPushNavigation(PushNotificationIntent intent) async {
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
    ref.read(shellTabProvider.notifier).setTab(ShellTab.home);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return false;
    }
    if (intent.type == PushNotificationType.morningRecommendation) {
      try {
        await ref.read(homeProvider.notifier).refresh();
      } catch (_) {
        // Home renders its existing actionable retry UI.
      }
      return true;
    }
    await openFeedbackEntry(context: context, ref: ref);
    return true;
  }
}
