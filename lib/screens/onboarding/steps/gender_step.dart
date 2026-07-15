import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../constants/app_strings.dart';

class SelectionOption {
  const SelectionOption({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;
}

class GenderStep extends StatelessWidget {
  const GenderStep({
    super.key,
    required this.selectedValue,
    required this.onSelected,
    required this.onNext,
  });

  static const options = [
    SelectionOption(
      label: AppStrings.male,
      value: 'male',
      icon: Icons.male_rounded,
    ),
    SelectionOption(
      label: AppStrings.female,
      value: 'female',
      icon: Icons.female_rounded,
    ),
    SelectionOption(
      label: AppStrings.unspecified,
      value: 'unspecified',
      icon: Icons.do_not_disturb_alt_rounded,
    ),
  ];

  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: KisouTheme.gapXl),
          const _StepHeader(
            icon: Icons.wc_rounded,
            title: AppStrings.genderPrompt,
          ),
          const SizedBox(height: KisouTheme.gapXl),
          for (final option in options) ...[
            _SelectionButton(
              label: option.label,
              icon: option.icon,
              isSelected: option.value == selectedValue,
              onTap: () => onSelected(option.value),
            ),
            const SizedBox(height: KisouTheme.gapM),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: selectedValue == null ? null : onNext,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text(AppStrings.next),
          ),
        ],
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  const _SelectionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

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
            color: isSelected
                ? c.accent.withValues(alpha: 0.10)
                : c.surface,
            border: Border.all(
              color: isSelected ? c.accent : c.hairline,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(KisouTheme.rSm),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? c.accent : c.softInk,
                ),
                const SizedBox(width: KisouTheme.gapM),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected ? c.accent : c.ink,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 20, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
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
