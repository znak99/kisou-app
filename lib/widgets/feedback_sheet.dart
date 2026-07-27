import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../constants/clothing_tags.dart';
import '../models/feedback.dart';
import '../providers/feedback_provider.dart';
import '../providers/home_provider.dart';
import '../utils/api_error.dart';
import '../utils/jp_date.dart';
import 'clothing_icon.dart';

/// Display order + labels for the "when were you outside?" multi-select.
/// Codes match the API's ALLOWED_TIME_SLOTS.
const _timeSlots = [
  (code: 'EARLY_MORNING', label: AppStrings.slotEarlyMorning),
  (code: 'MORNING', label: AppStrings.slotMorning),
  (code: 'FORENOON', label: AppStrings.slotForenoon),
  (code: 'AFTERNOON', label: AppStrings.slotAfternoon),
  (code: 'EVENING', label: AppStrings.slotEvening),
  (code: 'NIGHT', label: AppStrings.slotNight),
];

/// The server accepts back-dated feedback up to a week old.
const _maxBackdateDays = 7;

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
  DateTime _date = jstToday();
  final Set<String> _selectedSlots = {};
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
    if (initialFeedback != null) {
      _selectedTop = initialFeedback.actualTop;
      _selectedBottom = initialFeedback.actualBottom;
      _selectedOuter = initialFeedback.actualOuter;
      _selectedFeeling = initialFeedback.feedbackValue;
      _date = DateTime.tryParse(initialFeedback.date) ?? _date;
      _selectedSlots.addAll(initialFeedback.timeSlots ?? const []);
      return;
    }
    // First feedback of the day: preselect today's rank-1 recommendation —
    // most users wore (roughly) what the app suggested, so the common case
    // becomes "confirm and rate" instead of picking everything by hand.
    // ref.exists: never INITIALIZE home (and its network fetch) just for
    // defaults — only borrow it when the home tab already loaded it.
    final home = !ref.exists(homeProvider)
        ? null
        : ref
              .read(homeProvider)
              .maybeWhen(data: (value) => value, orElse: () => null);
    if (home == null || home.recommendations.isEmpty) {
      return;
    }
    final recommendations = [...home.recommendations]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final primary = recommendations.first;
    _selectedTop = primary.top;
    _selectedBottom = primary.bottom;
    _selectedOuter = primary.outer;
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
              date: formatIsoDate(_date),
              timeSlots: [
                for (final slot in _timeSlots)
                  if (_selectedSlots.contains(slot.code)) slot.code,
              ],
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = classifyApiError(error) == ApiErrorKind.unknown
              ? AppStrings.feedbackSubmitFailed
              : apiErrorMessage(error);
        });
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
                  color: context.kisou.hairline,
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
              // When: date (today by default, back-datable) + which parts of
              // the day the user was outside (multi-select) — review 5.
              _DateRow(
                date: _date,
                onTap: _isSubmitting ? null : _pickDate,
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.feedbackTimeSlotsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final slot in _timeSlots)
                    FilterChip(
                      label: Text(slot.label),
                      selected: _selectedSlots.contains(slot.code),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSlots.add(slot.code);
                          } else {
                            _selectedSlots.remove(slot.code);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
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

  Future<void> _pickDate() async {
    final today = jstToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: _maxBackdateDays)),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final isToday = date == jstToday();
    return Row(
      children: [
        Text(
          AppStrings.feedbackDateLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: c.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: KisouTheme.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isToday
                      ? '${AppStrings.feedbackDateToday}・${formatJpDate(date)}'
                      : formatJpDate(date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClothingIcon(
          code: code,
          type: type,
          size: 64,
          selected: selected,
          plain: true,
        ),
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
    final showSpinner = isSubmitting && selected;
    return OutlinedButton(
      onPressed: isSubmitting ? null : () => onTap(value),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? color.withValues(alpha: 0.12)
            : context.kisou.surface,
        foregroundColor: color,
        minimumSize: const Size.fromHeight(64),
        side: BorderSide(
          color: selected ? color : context.kisou.hairline,
          width: selected ? 2 : 1,
        ),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}
