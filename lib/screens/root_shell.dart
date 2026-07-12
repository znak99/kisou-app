import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/shell_provider.dart';
import '../widgets/ad_slot.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/feedback_action_button.dart';
import '../widgets/kisou_top_bar.dart';
import 'analysis/analysis_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

/// Root scaffold after login/onboarding: three tabs behind a persistent
/// bottom navigation, with an ad slot pinned above it on every tab.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  static const _tabs = [
    HomeScreen(),
    AnalysisScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    return Scaffold(
      backgroundColor: context.kisou.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            KisouTopBar(
              action: index == ShellTab.home
                  ? const FeedbackActionButton()
                  : null,
            ),
            Expanded(child: IndexedStack(index: index, children: _tabs)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdSlot(),
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
