import 'package:flutter/material.dart';

import '../../../constants/app_strings.dart';
import 'gender_step.dart';

class SensitivityStep extends StatelessWidget {
  const SensitivityStep({
    super.key,
    required this.coldSensitivity,
    required this.heatSensitivity,
    required this.onColdSelected,
    required this.onHeatSelected,
    required this.onNext,
  });

  static const coldOptions = [
    SelectionOption(label: AppStrings.coldHigh, value: 'high'),
    SelectionOption(label: AppStrings.normal, value: 'normal'),
    SelectionOption(label: AppStrings.coldLow, value: 'low'),
  ];

  static const heatOptions = [
    SelectionOption(label: AppStrings.heatHigh, value: 'high'),
    SelectionOption(label: AppStrings.normal, value: 'normal'),
    SelectionOption(label: AppStrings.heatLow, value: 'low'),
  ];

  final String? coldSensitivity;
  final String? heatSensitivity;
  final ValueChanged<String> onColdSelected;
  final ValueChanged<String> onHeatSelected;
  final VoidCallback onNext;

  bool get _canContinue => coldSensitivity != null && heatSensitivity != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            AppStrings.sensitivityPrompt,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          _QuestionGroup(
            title: AppStrings.coldQuestion,
            options: coldOptions,
            selectedValue: coldSensitivity,
            onSelected: onColdSelected,
          ),
          const SizedBox(height: 28),
          _QuestionGroup(
            title: AppStrings.heatQuestion,
            options: heatOptions,
            selectedValue: heatSensitivity,
            onSelected: onHeatSelected,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _canContinue ? onNext : null,
            child: const Text(AppStrings.next),
          ),
        ],
      ),
    );
  }
}

class _QuestionGroup extends StatelessWidget {
  const _QuestionGroup({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final List<SelectionOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            for (final option in options)
              ButtonSegment(value: option.value, label: Text(option.label)),
          ],
          selected: selectedValue == null ? <String>{} : {selectedValue!},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary.withValues(alpha: 0.12);
              }
              return null;
            }),
          ),
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              onSelected(values.first);
            }
          },
        ),
      ],
    );
  }
}
