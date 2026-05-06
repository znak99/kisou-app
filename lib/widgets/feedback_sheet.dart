import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../constants/clothing_tags.dart';
import '../models/feedback.dart';
import '../providers/feedback_provider.dart';
import 'clothing_icon.dart';

Future<bool?> showFeedbackSheet({
  required BuildContext context,
  required String? gender,
  required FeedbackResponse? initialFeedback,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) {
      return FeedbackSheet(gender: gender, initialFeedback: initialFeedback);
    },
  );
}

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({
    super.key,
    required this.gender,
    required this.initialFeedback,
  });

  final String? gender;
  final FeedbackResponse? initialFeedback;

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  var _step = 0;
  String? _selectedTop;
  String? _selectedBottom;
  String? _selectedOuter;
  String? _selectedFeeling;
  var _isSubmitting = false;
  String? _errorMessage;

  bool get _canContinue => _selectedTop != null && _selectedBottom != null;

  @override
  void initState() {
    super.initState();
    final initialFeedback = widget.initialFeedback;
    _selectedTop = initialFeedback?.actualTop;
    _selectedBottom = initialFeedback?.actualBottom;
    _selectedOuter = initialFeedback?.actualOuter;
    _selectedFeeling = initialFeedback?.feedbackValue;
  }

  Future<void> _submit(String feedbackValue) async {
    final top = _selectedTop;
    final bottom = _selectedBottom;
    if (top == null || bottom == null || _isSubmitting) {
      return;
    }

    setState(() {
      _selectedFeeling = feedbackValue;
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(feedbackProvider.notifier)
          .submit(
            FeedbackRequest(
              feedbackValue: feedbackValue,
              actualTop: top,
              actualBottom: bottom,
              actualOuter: _selectedOuter,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = AppStrings.feedbackSubmitFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KisouTheme.mistGray,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _step == 0 ? _buildClothingStep() : _buildFeelingStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClothingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.feedbackClothingTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              _OptionSection(
                title: AppStrings.feedbackTops,
                children: [
                  for (final top in ClothingTop.values)
                    _SelectableClothingOption(
                      code: top.apiCode,
                      type: ClothingIconType.top,
                      selected: _selectedTop == top.apiCode,
                      onTap: () => setState(() => _selectedTop = top.apiCode),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _OptionSection(
                title: AppStrings.feedbackBottoms,
                children: [
                  for (final bottom in _bottomOptions)
                    _SelectableClothingOption(
                      code: bottom.apiCode,
                      type: ClothingIconType.bottom,
                      selected: _selectedBottom == bottom.apiCode,
                      onTap: () {
                        setState(() => _selectedBottom = bottom.apiCode);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _OptionSection(
                title: AppStrings.feedbackOuter,
                children: [
                  _SelectableClothingOption(
                    code: null,
                    type: ClothingIconType.outer,
                    selected: _selectedOuter == null,
                    onTap: () => setState(() => _selectedOuter = null),
                  ),
                  for (final outer in ClothingOuter.values)
                    _SelectableClothingOption(
                      code: outer.apiCode,
                      type: ClothingIconType.outer,
                      selected: _selectedOuter == outer.apiCode,
                      onTap: () {
                        setState(() => _selectedOuter = outer.apiCode);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _canContinue ? () => setState(() => _step = 1) : null,
          child: const Text(AppStrings.next),
        ),
      ],
    );
  }

  Widget _buildFeelingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.feedbackFeelingTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _FeelingButton(
          label: AppStrings.feedbackCold,
          value: 'cold',
          icon: Icons.ac_unit,
          color: const Color(0xFF326FA8),
          selected: _selectedFeeling == 'cold',
          isSubmitting: _isSubmitting,
          onTap: _submit,
        ),
        const SizedBox(height: 12),
        _FeelingButton(
          label: AppStrings.feedbackPerfect,
          value: 'perfect',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF2E7D5B),
          selected: _selectedFeeling == 'perfect',
          isSubmitting: _isSubmitting,
          onTap: _submit,
        ),
        const SizedBox(height: 12),
        _FeelingButton(
          label: AppStrings.feedbackHot,
          value: 'hot',
          icon: Icons.wb_sunny_outlined,
          color: const Color(0xFFC65353),
          selected: _selectedFeeling == 'hot',
          isSubmitting: _isSubmitting,
          onTap: _submit,
        ),
        if (_isSubmitting) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: _isSubmitting ? null : () => setState(() => _step = 0),
          child: const Text(AppStrings.back),
        ),
      ],
    );
  }

  List<ClothingBottom> get _bottomOptions {
    if (widget.gender == 'male') {
      return [ClothingBottom.longPants, ClothingBottom.halfPants];
    }
    return ClothingBottom.values;
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 12, children: children),
      ],
    );
  }
}

class _SelectableClothingOption extends StatelessWidget {
  const _SelectableClothingOption({
    required this.code,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String? code;
  final ClothingIconType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: selected ? colorScheme.primary : KisouTheme.mistGray,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClothingIcon(code: code, type: type, size: 64),
      ),
    );
  }
}

class _FeelingButton extends StatelessWidget {
  const _FeelingButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isSubmitting,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isSubmitting;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isSubmitting ? null : () => onTap(value),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? color.withValues(alpha: 0.08)
            : Colors.white,
        foregroundColor: color,
        minimumSize: const Size.fromHeight(60),
        side: BorderSide(color: selected ? color : KisouTheme.mistGray),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon), const SizedBox(width: 10), Text(label)],
      ),
    );
  }
}
