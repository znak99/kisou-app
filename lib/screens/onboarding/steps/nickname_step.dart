import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../constants/app_strings.dart';

class NicknameStep extends StatefulWidget {
  const NicknameStep({
    super.key,
    required this.initialValue,
    required this.onNext,
  });

  final String initialValue;
  final ValueChanged<String> onNext;

  @override
  State<NicknameStep> createState() => _NicknameStepState();
}

class _NicknameStepState extends State<NicknameStep> {
  late final TextEditingController _controller;

  bool get _canContinue => _controller.text.trim().length >= 2;

  bool get _showMinLengthHint {
    final trimmed = _controller.text.trim();
    return trimmed.isNotEmpty && trimmed.length < 2;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: KisouTheme.gapXl),
          const _StepHeader(
            icon: Icons.person_rounded,
            title: AppStrings.nicknamePrompt,
          ),
          const SizedBox(height: KisouTheme.gapXl),
          TextField(
            controller: _controller,
            maxLength: 10,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: AppStrings.nicknameHint,
              prefixIcon: Icon(Icons.badge_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_showMinLengthHint) ...[
            const SizedBox(height: KisouTheme.gapXs),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: KisouTheme.gapXs),
                Expanded(
                  child: Text(
                    AppStrings.nicknameMinLength,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: _canContinue
                ? () => widget.onNext(_controller.text.trim())
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text(AppStrings.next),
          ),
        ],
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
