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
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  static const _tabs = [HomeScreen(), AnalysisScreen(), ProfileScreen()];

  // Only tabs the user has actually opened are built; others stay as an empty
  // placeholder so their providers don't fire on startup (audit B23). Once
  // visited a tab is kept alive (IndexedStack preserves its state).
  final Set<int> _visitedTabs = {ShellTab.home};

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
              action: index == ShellTab.home
                  ? const FeedbackActionButton()
                  : null,
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
