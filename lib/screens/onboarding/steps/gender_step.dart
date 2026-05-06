import 'package:flutter/material.dart';

import '../../../constants/app_strings.dart';

class SelectionOption {
  const SelectionOption({required this.label, required this.value});

  final String label;
  final String value;
}

class GenderStep extends StatelessWidget {
  const GenderStep({
    super.key,
    required this.selectedValue,
    required this.onSelected,
    required this.onNext,
  });

  static const options = [
    SelectionOption(label: AppStrings.male, value: 'male'),
    SelectionOption(label: AppStrings.female, value: 'female'),
    SelectionOption(label: AppStrings.unspecified, value: 'unspecified'),
  ];

  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            AppStrings.genderPrompt,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          for (final option in options) ...[
            _SelectionButton(
              label: option.label,
              isSelected: option.value == selectedValue,
              onTap: () => onSelected(option.value),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          FilledButton(
            onPressed: selectedValue == null ? null : onNext,
            child: const Text(AppStrings.next),
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
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: isSelected ? colorScheme.primary : const Color(0xFFE8F0F4),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
