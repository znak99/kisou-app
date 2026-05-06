import 'package:flutter/material.dart';

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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            AppStrings.timePrompt,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.changeLater,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 32),
          _TimeTile(
            label: AppStrings.departureTime,
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
          const SizedBox(height: 12),
          _TimeTile(
            label: AppStrings.returnTime,
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
          const Spacer(),
          FilledButton(
            onPressed: isSaving ? null : onComplete,
            child: isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.setTime),
          ),
          const SizedBox(height: 12),
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
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8F0F4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              _formatTime(time),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
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
