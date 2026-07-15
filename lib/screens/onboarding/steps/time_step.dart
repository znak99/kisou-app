import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../constants/app_strings.dart';

class TimeStep extends StatelessWidget {
  const TimeStep({
    super.key,
    required this.departureTime,
    required this.returnTime,
    required this.onDepartureChanged,
    required this.onReturnChanged,
    required this.onComplete,
    required this.onSkip,
    required this.isSaving,
  });

  final TimeOfDay departureTime;
  final TimeOfDay returnTime;
  final ValueChanged<TimeOfDay> onDepartureChanged;
  final ValueChanged<TimeOfDay> onReturnChanged;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Padding(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: KisouTheme.gapXl),
          const _StepHeader(
            icon: Icons.schedule_rounded,
            title: AppStrings.timePrompt,
          ),
          const SizedBox(height: KisouTheme.gapM),
          Text(
            AppStrings.changeLater,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: KisouTheme.gapXl),
          _TimeTile(
            label: AppStrings.departureTime,
            icon: Icons.logout_rounded,
            time: departureTime,
            onTap: isSaving
                ? null
                : () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: departureTime,
                    );
                    if (selected != null) {
                      onDepartureChanged(selected);
                    }
                  },
          ),
          const SizedBox(height: KisouTheme.gapM),
          _TimeTile(
            label: AppStrings.returnTime,
            icon: Icons.login_rounded,
            time: returnTime,
            onTap: isSaving
                ? null
                : () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: returnTime,
                    );
                    if (selected != null) {
                      onReturnChanged(selected);
                    }
                  },
          ),
          const SizedBox(height: KisouTheme.gapM),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.softInk),
              const SizedBox(width: KisouTheme.gapXs),
              Expanded(
                child: Text(
                  AppStrings.timeApproximateNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: isSaving ? null : onComplete,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: const Text(AppStrings.setTime),
          ),
          const SizedBox(height: KisouTheme.gapM),
          TextButton(
            onPressed: isSaving ? null : onSkip,
            child: const Text(AppStrings.skip),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.icon,
    required this.time,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final TimeOfDay time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KisouTheme.rSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KisouTheme.gapL,
            vertical: KisouTheme.gapL,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.hairline),
            borderRadius: BorderRadius.circular(KisouTheme.rSm),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: KisouTheme.gapM),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _formatTime(time),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.accent,
                ),
              ),
              const SizedBox(width: KisouTheme.gapS),
              Icon(Icons.expand_more_rounded, size: 20, color: c.softInk),
            ],
          ),
        ),
      ),
    );
  }
}

String formatApiTime(TimeOfDay time) => _formatTime(time);

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Leading icon + prompt title shown at the top of each onboarding step.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(KisouTheme.gapM),
          decoration: BoxDecoration(
            gradient: c.accentGradient,
            borderRadius: BorderRadius.circular(KisouTheme.rSm),
            boxShadow: c.tileShadow,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: KisouTheme.gapM),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }
}
