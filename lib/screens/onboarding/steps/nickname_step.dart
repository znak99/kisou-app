import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  bool get _canContinue => _controller.text.trim().isNotEmpty;

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            AppStrings.nicknamePrompt,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            maxLength: 10,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: AppStrings.nicknameHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _canContinue
                ? () => widget.onNext(_controller.text.trim())
                : null,
            child: const Text(AppStrings.next),
          ),
        ],
      ),
    );
  }
}
