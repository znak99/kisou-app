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
  (
    code: 'EARLY_MORNING',
    label: AppStrings.slotEarlyMorning,
    range: '4〜7時',
    spokenRange: '4時から7時',
  ),
  (
    code: 'MORNING',
    label: AppStrings.slotMorning,
    range: '8〜11時',
    spokenRange: '8時から11時',
  ),
  (
    code: 'AFTERNOON',
    label: AppStrings.slotAfternoon,
    range: '12〜15時',
    spokenRange: '12時から15時',
  ),
  (
    code: 'EVENING',
    label: AppStrings.slotEvening,
    range: '16〜19時',
    spokenRange: '16時から19時',
  ),
  (
    code: 'NIGHT',
    label: AppStrings.slotNight,
    range: '20〜23時',
    spokenRange: '20時から23時',
  ),
  (
    code: 'LATE_NIGHT',
    label: AppStrings.slotLateNight,
    range: '0〜3時',
    spokenRange: '0時から3時',
  ),
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
  static const _stepCount = 3;

  var _step = 0;
  DateTime _date = jstToday();
  var _showDateSelection = false;
  var _isLoadingRecent = false;
  Object? _recentError;
  List<FeedbackRecentDay>? _recentDays;
  FeedbackResponse? _loadedFeedback;
  final ScrollController _clothingScrollController = ScrollController();
  final Set<String> _selectedSlots = {};
  String? _selectedTop;
  String? _selectedBottom;
  String? _selectedOuter;
  var _outerSelectionMade = false;
  String? _selectedFeeling;
  var _isSubmitting = false;
  var _isDirty = false;
  var _showTimeSlotError = false;
  String? _errorMessage;

  bool get _hasRequiredClothing =>
      _selectedTop != null && _selectedBottom != null && _outerSelectionMade;

  @override
  void initState() {
    super.initState();
    final initialFeedback = widget.initialFeedback;
    if (initialFeedback != null) {
      _applyFeedback(initialFeedback);
    }
  }

  void _applyFeedback(FeedbackResponse feedback) {
    _loadedFeedback = feedback;
    _selectedTop = feedback.actualTop;
    _selectedBottom = feedback.actualBottom;
    _selectedOuter = feedback.actualOuter;
    _outerSelectionMade = true;
    _selectedFeeling = feedback.feedbackValue;
    _date = DateTime.tryParse(feedback.date) ?? _date;
    _selectedSlots
      ..clear()
      ..addAll(feedback.timeSlots ?? const []);
    _isDirty = false;
    _showTimeSlotError = false;
  }

  void _applyTodayRecommendation() {
    // Recommendation values are applied only after an explicit user action.
    // Silent defaults would bias feedback toward what KISOU suggested rather
    // than what the user actually wore.
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
    _outerSelectionMade = true;
    _isDirty = true;
  }

  Future<void> _submit() async {
    final top = _selectedTop;
    final bottom = _selectedBottom;
    final feedbackValue = _selectedFeeling;
    if (top == null ||
        bottom == null ||
        feedbackValue == null ||
        !_outerSelectionMade ||
        _selectedSlots.isEmpty ||
        _isSubmitting) {
      return;
    }

    setState(() {
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

  void _continueToFeeling() {
    if (!_hasRequiredClothing) {
      return;
    }
    setState(() => _step = 2);
  }

  void _continueToClothing() {
    if (_selectedSlots.isEmpty) {
      setState(() => _showTimeSlotError = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_clothingScrollController.hasClients) {
          return;
        }
        if (MediaQuery.disableAnimationsOf(context)) {
          _clothingScrollController.jumpTo(0);
        } else {
          _clothingScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      });
      return;
    }
    setState(() {
      _showTimeSlotError = false;
      _step = 1;
    });
  }

  @override
  void dispose() {
    _clothingScrollController.dispose();
    super.dispose();
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
            if (!_showDateSelection) ...[
              Semantics(
                label: '${_step + 1}/$_stepCount',
                value: '${_step + 1}/$_stepCount',
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / _stepCount,
                          minHeight: 4,
                          backgroundColor: context.kisou.hairline,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.kisou.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: KisouTheme.gapM),
                    Text(
                      '${_step + 1}/$_stepCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KisouTheme.gapM),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: _showDateSelection
                    ? _buildDateSelection()
                    : _step == 0
                    ? _buildWhenStep()
                    : _step == 1
                    ? _buildClothingStep()
                    : _buildFeelingStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenStep() {
    return Column(
      key: const ValueKey('when-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.feedbackWhenTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            controller: _clothingScrollController,
            children: [
              _DateRow(
                date: _date,
                onTap: _isSubmitting ? null : _openDateSelection,
              ),
              const SizedBox(height: KisouTheme.gapS),
              _FeedbackRecordStatus(exists: _loadedFeedback != null),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    AppStrings.feedbackTimeSlotsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: KisouTheme.gapS),
                  const _RequiredBadge(),
                ],
              ),
              const SizedBox(height: 4),
              if (_showTimeSlotError)
                Text(
                  AppStrings.feedbackTimeSlotsRequired,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
                    height: 1.35,
                  ),
                )
              else
                Text(
                  AppStrings.feedbackTimeSlotsHelp,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk),
                ),
              const SizedBox(height: KisouTheme.gapS),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final width = (constraints.maxWidth - spacing * 2) / 3;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final slot in _timeSlots)
                        SizedBox(
                          width: width,
                          child: _TimeSlotButton(
                            label: slot.label,
                            range: slot.range,
                            spokenRange: slot.spokenRange,
                            selected: _selectedSlots.contains(slot.code),
                            onTap: () {
                              setState(() {
                                _isDirty = true;
                                if (_selectedSlots.contains(slot.code)) {
                                  _selectedSlots.remove(slot.code);
                                } else {
                                  _selectedSlots.add(slot.code);
                                }
                                if (_selectedSlots.isNotEmpty) {
                                  _showTimeSlotError = false;
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _continueToClothing,
          child: const Text(AppStrings.next),
        ),
      ],
    );
  }

  Widget _buildClothingStep() {
    return Column(
      key: const ValueKey('clothing-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.feedbackClothingTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: KisouTheme.gapXs),
        Text(
          AppStrings.feedbackClothingHelp,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            controller: _clothingScrollController,
            children: [
              if (_isSameDate(_date, jstToday()) &&
                  _loadedFeedback == null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(_applyTodayRecommendation),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text(AppStrings.feedbackUseRecommendation),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _OptionSection(
                title: AppStrings.feedbackOuter,
                children: [
                  _SelectableClothingOption(
                    code: null,
                    type: ClothingIconType.outer,
                    selected: _outerSelectionMade && _selectedOuter == null,
                    onTap: () => setState(() {
                      _isDirty = true;
                      _outerSelectionMade = true;
                      _selectedOuter = null;
                    }),
                  ),
                  for (final outer in ClothingOuter.values)
                    _SelectableClothingOption(
                      code: outer.apiCode,
                      type: ClothingIconType.outer,
                      selected:
                          _outerSelectionMade &&
                          _selectedOuter == outer.apiCode,
                      onTap: () {
                        setState(() {
                          _isDirty = true;
                          _outerSelectionMade = true;
                          _selectedOuter = outer.apiCode;
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
                      onTap: () => setState(() {
                        _isDirty = true;
                        _selectedTop = top.apiCode;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _OptionSection(
                title: AppStrings.feedbackBottoms,
                children: [
                  for (final bottom in ClothingBottom.values)
                    _SelectableClothingOption(
                      code: bottom.apiCode,
                      type: ClothingIconType.bottom,
                      selected: _selectedBottom == bottom.apiCode,
                      onTap: () {
                        setState(() {
                          _isDirty = true;
                          _selectedBottom = bottom.apiCode;
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _hasRequiredClothing ? _continueToFeeling : null,
          child: const Text(AppStrings.next),
        ),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text(AppStrings.back),
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
          onTap: (value) => setState(() {
            _selectedFeeling = value;
            _isDirty = true;
            _errorMessage = null;
          }),
        ),
        const SizedBox(height: 12),
        _FeelingButton(
          label: AppStrings.feedbackPerfect,
          value: 'perfect',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF2E7D5B),
          selected: _selectedFeeling == 'perfect',
          isSubmitting: _isSubmitting,
          onTap: (value) => setState(() {
            _selectedFeeling = value;
            _isDirty = true;
            _errorMessage = null;
          }),
        ),
        const SizedBox(height: 12),
        _FeelingButton(
          label: AppStrings.feedbackHot,
          value: 'hot',
          icon: Icons.wb_sunny_outlined,
          color: const Color(0xFFC65353),
          selected: _selectedFeeling == 'hot',
          isSubmitting: _isSubmitting,
          onTap: (value) => setState(() {
            _selectedFeeling = value;
            _isDirty = true;
            _errorMessage = null;
          }),
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
        FilledButton(
          onPressed: _selectedFeeling == null || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _loadedFeedback == null
                      ? AppStrings.feedbackSave
                      : AppStrings.feedbackUpdateSave,
                ),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : () => setState(() => _step = 1),
          child: const Text(AppStrings.back),
        ),
      ],
    );
  }

  Widget _buildDateSelection() {
    return Column(
      key: const ValueKey('date-selection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: AppStrings.back,
              onPressed: () => setState(() => _showDateSelection = false),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: KisouTheme.gapXs),
            Expanded(
              child: Text(
                AppStrings.feedbackDateSelectTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Text(
            AppStrings.feedbackDateSelectHelp,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk),
          ),
        ),
        const SizedBox(height: KisouTheme.gapM),
        Expanded(
          child: switch ((_isLoadingRecent, _recentError, _recentDays)) {
            (true, _, _) => const _RecentFeedbackSkeleton(),
            (false, final error?, _) => _RecentFeedbackError(
              error: error,
              onRetry: _loadRecentFeedback,
            ),
            (false, _, final days?) => ListView.separated(
              itemCount: days.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: context.kisou.hairline),
              itemBuilder: (context, index) {
                final day = days[index];
                return _RecentDateRow(
                  day: day,
                  selected: _isSameDate(day.date, _date),
                  onTap: () => _selectRecentDay(day),
                );
              },
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  void _openDateSelection() {
    setState(() => _showDateSelection = true);
    _loadRecentFeedback();
  }

  Future<void> _loadRecentFeedback() async {
    if (_isLoadingRecent) {
      return;
    }
    setState(() {
      _isLoadingRecent = true;
      _recentError = null;
    });
    try {
      final response = await ref
          .read(feedbackProvider.notifier)
          .getRecentFeedback();
      if (mounted) {
        setState(() => _recentDays = response.days);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _recentError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRecent = false);
      }
    }
  }

  Future<void> _selectRecentDay(FeedbackRecentDay day) async {
    if (_isSameDate(day.date, _date)) {
      setState(() => _showDateSelection = false);
      return;
    }
    if (_isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            content: const Text(AppStrings.feedbackDiscardTitle),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(AppStrings.feedbackChangeDate),
              ),
            ],
          );
        },
      );
      if (discard != true || !mounted) {
        return;
      }
    }

    setState(() {
      _date = day.date;
      _step = 0;
      _selectedSlots.clear();
      _selectedTop = null;
      _selectedBottom = null;
      _selectedOuter = null;
      _outerSelectionMade = false;
      _selectedFeeling = null;
      _loadedFeedback = null;
      _errorMessage = null;
      _showTimeSlotError = false;
      if (day.feedback != null) {
        _applyFeedback(day.feedback!);
      }
      _isDirty = false;
      _showDateSelection = false;
    });
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _FeedbackRecordStatus extends StatelessWidget {
  const _FeedbackRecordStatus({required this.exists});

  final bool exists;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final color = exists ? c.accent : c.softInk;
    return Row(
      children: [
        Icon(
          exists ? Icons.edit_outlined : Icons.add_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: KisouTheme.gapXs),
        Expanded(
          child: Text(
            exists
                ? AppStrings.feedbackEditingSaved
                : AppStrings.feedbackNotRecorded,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppStrings.feedbackRequired,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimeSlotButton extends StatelessWidget {
  const _TimeSlotButton({
    required this.label,
    required this.range,
    required this.spokenRange,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String range;
  final String spokenRange;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final largeText = usesLargeText(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label、$spokenRange',
      onTap: onTap,
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(largeText ? 88 : 64),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            backgroundColor: selected
                ? c.accent.withValues(alpha: 0.1)
                : c.surface,
            side: BorderSide(
              color: selected ? c.accent : c.hairline,
              width: selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded, size: 15, color: c.accent),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? c.accent : c.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                range,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 11, color: c.softInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDateRow extends StatelessWidget {
  const _RecentDateRow({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final FeedbackRecentDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = jstToday();
    final yesterday = today.subtract(const Duration(days: 1));
    final relative =
        day.date.year == today.year &&
            day.date.month == today.month &&
            day.date.day == today.day
        ? AppStrings.feedbackDateToday
        : day.date.year == yesterday.year &&
              day.date.month == yesterday.month &&
              day.date.day == yesterday.day
        ? AppStrings.feedbackDateYesterday
        : null;
    final hasFeedback = day.feedback != null;
    final semanticLabel = [
      ?relative,
      formatJpDate(day.date),
      if (hasFeedback) AppStrings.feedbackRecorded,
    ].join('、');
    final c = context.kisou;
    final largeText = usesLargeText(context);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KisouTheme.rSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KisouTheme.gapS,
                vertical: KisouTheme.gapS,
              ),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RecentDateLabel(
                          relative: relative,
                          date: day.date,
                          selected: selected,
                        ),
                        if (hasFeedback) ...[
                          const SizedBox(height: KisouTheme.gapXs),
                          const _RecordedBadge(),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _RecentDateLabel(
                            relative: relative,
                            date: day.date,
                            selected: selected,
                          ),
                        ),
                        if (hasFeedback) const _RecordedBadge(),
                        if (selected) ...[
                          const SizedBox(width: KisouTheme.gapS),
                          Icon(Icons.check_rounded, color: c.accent),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentDateLabel extends StatelessWidget {
  const _RecentDateLabel({
    required this.relative,
    required this.date,
    required this.selected,
  });

  final String? relative;
  final DateTime date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            relative ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.softInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            formatJpDate(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? c.accent : c.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordedBadge extends StatelessWidget {
  const _RecordedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppStrings.feedbackRecorded,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: c.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecentFeedbackSkeleton extends StatelessWidget {
  const _RecentFeedbackSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: AppStrings.feedbackRecentLoading,
      child: ExcludeSemantics(
        child: ListView.separated(
          itemCount: _maxBackdateDays + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 1),
          itemBuilder: (context, index) {
            return Container(
              height: 56,
              decoration: BoxDecoration(
                color: context.kisou.surfaceAlt,
                borderRadius: BorderRadius.circular(KisouTheme.rSm),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecentFeedbackError extends StatelessWidget {
  const _RecentFeedbackError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 36,
          ),
          const SizedBox(height: KisouTheme.gapM),
          const Text(AppStrings.feedbackRecentFailed),
          const SizedBox(height: KisouTheme.gapM),
          FilledButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final today = jstToday();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final largeText = usesLargeText(context);
    final value = isToday
        ? '${AppStrings.feedbackDateToday} ${formatJpDate(date)}'
        : formatJpDate(date);
    final spokenValue = isToday
        ? '${AppStrings.feedbackDateToday}、${formatJpDateSpoken(date)}'
        : formatJpDateSpoken(date);
    final picker = Semantics(
      button: true,
      enabled: onTap != null,
      label: AppStrings.feedbackDateLabel,
      value: spokenValue,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: c.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: c.accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final label = Text(
      AppStrings.feedbackDateLabel,
      style: Theme.of(context).textTheme.titleMedium,
    );
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: KisouTheme.gapS),
          Align(alignment: Alignment.centerRight, child: picker),
        ],
      );
    }
    return Row(
      children: [
        label,
        const SizedBox(width: KisouTheme.gapM),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: picker),
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
    final label = switch (type) {
      ClothingIconType.top =>
        ClothingTop.fromCode(code)?.displayName ?? AppStrings.unknownClothing,
      ClothingIconType.bottom =>
        ClothingBottom.fromCode(code)?.displayName ??
            AppStrings.unknownClothing,
      ClothingIconType.outer =>
        code == null
            ? AppStrings.noOuter
            : ClothingOuter.fromCode(code)?.displayName ??
                  AppStrings.unknownClothing,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            width: 84,
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: selected
                  ? context.kisou.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ClothingIcon(
                    code: code,
                    type: type,
                    size: 64,
                    selected: selected,
                    plain: true,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: context.kisou.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.kisou.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
    return Semantics(
      selected: selected,
      child: OutlinedButton(
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
              Icon(icon),
            const SizedBox(width: 10),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
