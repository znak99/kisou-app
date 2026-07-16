import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../models/feedback.dart';
import '../models/user.dart';
import '../providers/feedback_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/home_provider.dart';
import '../providers/user_provider.dart';
import 'feedback_sheet.dart';

/// The home tab's toolbar action: opens the daily feedback sheet, reflecting
/// whether today's feedback has already been submitted. Sources its state from
/// providers so it can live in the shared [KisouTopBar] rather than inside the
/// home screen body.
class FeedbackActionButton extends ConsumerWidget {
  const FeedbackActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackState = ref.watch(feedbackProvider);
    final user = ref
        .watch(userProvider)
        .when(
          data: (value) => value,
          error: (_, _) => null,
          loading: () => null,
        );
    return feedbackState.when(
      data: (status) {
        final feedback = status.feedback;
        final submitted = status.exists && feedback != null;
        return _pill(
          context: context,
          icon: submitted
              ? Icons.check_circle_rounded
              : Icons.rate_review_outlined,
          label: submitted
              ? AppStrings.feedbackChange
              : AppStrings.feedbackButton,
          onTap: () => _openFeedbackSheet(
            context: context,
            ref: ref,
            user: user,
            initialFeedback: feedback,
          ),
        );
      },
      error: (error, _) => _pill(
        context: context,
        icon: Icons.refresh_rounded,
        label: AppStrings.retry,
        onTap: () => ref.read(feedbackProvider.notifier).refresh(),
      ),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _pill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final c = context.kisou;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: KisouTheme.accent),
              const SizedBox(width: KisouTheme.gapXs),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ],
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
      // Feedback shifts the personal offset, so tomorrow's recommendation is
      // stale too. invalidate (not refresh) so an unvisited 予報 tab doesn't
      // get initialized just to be refreshed (lazy-tab principle, audit B23).
      ref.invalidate(forecastTomorrowProvider);
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
