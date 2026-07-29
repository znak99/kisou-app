import 'package:flutter/material.dart';

import '../../../config/theme.dart';
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
    SelectionOption(
      label: AppStrings.coldHigh,
      value: 'high',
      icon: Icons.ac_unit_rounded,
    ),
    SelectionOption(
      label: AppStrings.normal,
      value: 'normal',
      icon: Icons.sentiment_neutral_rounded,
    ),
    SelectionOption(
      label: AppStrings.coldLow,
      value: 'low',
      icon: Icons.wb_sunny_rounded,
    ),
  ];

  static const heatOptions = [
    SelectionOption(
      label: AppStrings.heatHigh,
      value: 'high',
      icon: Icons.local_fire_department_rounded,
    ),
    SelectionOption(
      label: AppStrings.normal,
      value: 'normal',
      icon: Icons.sentiment_neutral_rounded,
    ),
    SelectionOption(
      label: AppStrings.heatLow,
      value: 'low',
      icon: Icons.ac_unit_rounded,
    ),
  ];

  final String? coldSensitivity;
  final String? heatSensitivity;
  final ValueChanged<String> onColdSelected;
  final ValueChanged<String> onHeatSelected;
  final VoidCallback onNext;

  bool get _canContinue => coldSensitivity != null && heatSensitivity != null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - KisouTheme.pagePad * 2;
        final useVertical = contentWidth < 340 || usesLargeText(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(KisouTheme.pagePad),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - KisouTheme.pagePad * 2,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: KisouTheme.gapXl),
                  const _StepHeader(
                    icon: Icons.thermostat_rounded,
                    title: AppStrings.sensitivityPrompt,
                  ),
                  const SizedBox(height: KisouTheme.gapXl),
                  _QuestionGroup(
                    title: AppStrings.coldQuestion,
                    icon: Icons.ac_unit_rounded,
                    options: coldOptions,
                    selectedValue: coldSensitivity,
                    onSelected: onColdSelected,
                    vertical: useVertical,
                  ),
                  const SizedBox(height: KisouTheme.gapXl),
                  _QuestionGroup(
                    title: AppStrings.heatQuestion,
                    icon: Icons.wb_sunny_rounded,
                    options: heatOptions,
                    selectedValue: heatSensitivity,
                    onSelected: onHeatSelected,
                    vertical: useVertical,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _canContinue ? onNext : null,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text(AppStrings.next),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuestionGroup extends StatelessWidget {
  const _QuestionGroup({
    required this.title,
    required this.icon,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.vertical,
  });

  final String title;
  final IconData icon;
  final List<SelectionOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: c.accent),
            const SizedBox(width: KisouTheme.gapS),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: KisouTheme.gapM),
        if (vertical)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                _VerticalChoiceButton(
                  option: options[index],
                  selected: selectedValue == options[index].value,
                  onPressed: () => onSelected(options[index].value),
                ),
                if (index < options.length - 1)
                  const SizedBox(height: KisouTheme.gapS),
              ],
            ],
          )
        else
          SegmentedButton<String>(
            segments: [
              for (final option in options)
                ButtonSegment(
                  value: option.value,
                  label: Text(option.label),
                  icon: option.icon == null
                      ? null
                      : Icon(option.icon, size: 18),
                ),
            ],
            selected: selectedValue == null ? <String>{} : {selectedValue!},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return c.accent.withValues(alpha: 0.12);
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

class _VerticalChoiceButton extends StatelessWidget {
  const _VerticalChoiceButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final SelectionOption option;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Semantics(
      selected: selected,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: KisouTheme.gapL,
            vertical: KisouTheme.gapM,
          ),
          backgroundColor: selected
              ? c.accent.withValues(alpha: 0.12)
              : c.surface,
          side: BorderSide(color: selected ? c.accent : c.hairline),
        ),
        icon: Icon(option.icon, size: 18),
        label: Text(option.label),
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
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ],
    );
  }
}
