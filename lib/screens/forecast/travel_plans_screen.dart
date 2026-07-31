import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/travel_plan.dart';
import '../../providers/travel_plan_provider.dart';
import '../../utils/jp_date.dart';

/// Compact device-local travel summary shown in the forecast tab.
class TravelUpcomingSection extends ConsumerWidget {
  const TravelUpcomingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(travelPlanProvider);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.kisou;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.travelSectionTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openManager(context),
              child: const Text(AppStrings.travelManage),
            ),
          ],
        ),
        const SizedBox(height: KisouTheme.gapXs),
        state.when(
          loading: () => _TravelSurface(
            child: Semantics(
              label: AppStrings.forecastLoading,
              liveRegion: true,
              child: const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          error: (_, _) => _TravelSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppStrings.travelLoadFailed),
                const SizedBox(height: KisouTheme.gapS),
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(travelPlanProvider.notifier).retry();
                  },
                  child: const Text(AppStrings.retry),
                ),
              ],
            ),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return _TravelSurface(
                child: InkWell(
                  borderRadius: BorderRadius.circular(KisouTheme.rSm),
                  onTap: () => showTravelPlanEditor(context: context, ref: ref),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Row(
                      children: [
                        Icon(
                          Icons.luggage_outlined,
                          color: colors.accent,
                          size: 28,
                        ),
                        const SizedBox(width: KisouTheme.gapM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.travelEmptyTitle,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.travelEmptyBody,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.softInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.add_rounded, color: colors.accent),
                      ],
                    ),
                  ),
                ),
              );
            }
            final visiblePlans = plans.take(3).toList(growable: false);
            return _TravelSurface(
              child: Column(
                children: [
                  for (var index = 0; index < visiblePlans.length; index++) ...[
                    if (index > 0)
                      Divider(height: KisouTheme.gapL, color: colors.hairline),
                    _CompactTravelRow(
                      plan: visiblePlans[index],
                      onTap: () => _openManager(
                        context,
                        focusPlanId: visiblePlans[index].id,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openManager(BuildContext context, {int? focusPlanId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TravelPlansScreen(focusPlanId: focusPlanId),
      ),
    );
  }
}

class _TravelSurface extends StatelessWidget {
  const _TravelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KisouTheme.cardPad),
      decoration: BoxDecoration(
        color: context.kisou.surface,
        borderRadius: BorderRadius.circular(KisouTheme.rMd),
        border: Border.all(color: context.kisou.hairline),
      ),
      child: child,
    );
  }
}

class _CompactTravelRow extends StatelessWidget {
  const _CompactTravelRow({required this.plan, required this.onTap});

  final TravelPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final city = majorCityByCode(plan.cityCode);
    if (city == null) {
      return const SizedBox.shrink();
    }
    final colors = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final departure = plan.departureOnJstClock;
    final dDay = plan.dDayAt(DateTime.now());
    return Semantics(
      button: true,
      label:
          '${city.regionName}、${AppStrings.travelDdaySpoken(dDay)}、'
          '${formatJpDateSpoken(departure)}、${_formatTime(departure)}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KisouTheme.rSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KisouTheme.gapS,
                    vertical: KisouTheme.gapXs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppStrings.travelDday(dDay),
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: KisouTheme.gapM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.regionName,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        AppStrings.travelDateTime(
                          formatJpDate(departure),
                          _formatTime(departure),
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.softInk,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.softInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TravelPlansScreen extends ConsumerStatefulWidget {
  const TravelPlansScreen({super.key, this.focusPlanId});

  final int? focusPlanId;

  @override
  ConsumerState<TravelPlansScreen> createState() => _TravelPlansScreenState();
}

class _TravelPlansScreenState extends ConsumerState<TravelPlansScreen> {
  bool _focusHandled = false;

  @override
  Widget build(BuildContext context) {
    final plansState = ref.watch(travelPlanProvider);
    _handleNotificationTarget(plansState);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.travelPlansTitle)),
      floatingActionButton:
          plansState.value != null && plansState.value!.length >= maxTravelPlans
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showTravelPlanEditor(context: context, ref: ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text(AppStrings.travelAdd),
            ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(travelPlanProvider.notifier).refreshAndReconcile(),
        child: plansState.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 240),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 120),
              Text(
                AppStrings.travelLoadFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: KisouTheme.gapM),
              FilledButton(
                onPressed: () {
                  ref.read(travelPlanProvider.notifier).retry();
                },
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    size: 56,
                    color: context.kisou.softInk,
                  ),
                  const SizedBox(height: KisouTheme.gapL),
                  Text(
                    AppStrings.travelEmptyTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KisouTheme.gapS),
                  Text(
                    AppStrings.travelEmptyBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.kisou.softInk,
                    ),
                  ),
                ],
              );
            }
            final ordered = [...plans];
            final focusId = widget.focusPlanId;
            if (focusId != null) {
              ordered.sort((left, right) {
                if (left.id == focusId) return -1;
                if (right.id == focusId) return 1;
                return left.departureAtUtc.compareTo(right.departureAtUtc);
              });
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              itemCount: ordered.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: KisouTheme.gapM),
              itemBuilder: (context, index) {
                final plan = ordered[index];
                return _TravelPlanCard(
                  plan: plan,
                  highlighted: plan.id == focusId,
                  onEdit: () => showTravelPlanEditor(
                    context: context,
                    ref: ref,
                    existing: plan,
                  ),
                  onDelete: () => _delete(plan),
                  onOpenSettings:
                      plan.syncState ==
                          TravelNotificationSyncState.blockedPermission
                      ? () => ref
                            .read(travelPlanProvider.notifier)
                            .openNotificationSettings()
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleNotificationTarget(AsyncValue<List<TravelPlan>> state) {
    final focusId = widget.focusPlanId;
    if (_focusHandled || focusId == null || !state.hasValue) {
      return;
    }
    _focusHandled = true;
    final found = state.value!.any((plan) => plan.id == focusId);
    if (!found) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.travelPlanNotFound)),
          );
        }
      });
    }
  }

  Future<void> _delete(TravelPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.travelDeleteTitle),
        content: const Text(AppStrings.travelDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.travelDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(travelPlanProvider.notifier).delete(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.travelDeleted)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.travelDeleteFailed)),
        );
      }
    }
  }
}

class _TravelPlanCard extends StatelessWidget {
  const _TravelPlanCard({
    required this.plan,
    required this.highlighted,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenSettings,
  });

  final TravelPlan plan;
  final bool highlighted;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final city = majorCityByCode(plan.cityCode);
    if (city == null) {
      return const SizedBox.shrink();
    }
    final colors = context.kisou;
    final textTheme = Theme.of(context).textTheme;
    final departure = plan.departureOnJstClock;
    final dDay = plan.dDayAt(DateTime.now());
    final status = _notificationStatus(plan);
    return Semantics(
      container: true,
      label:
          '${city.regionName}、${AppStrings.travelDdaySpoken(dDay)}、'
          '${formatJpDateSpoken(departure)}、${_formatTime(departure)}',
      child: Container(
        padding: const EdgeInsets.all(KisouTheme.cardPad),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(KisouTheme.rMd),
          border: Border.all(
            color: highlighted ? colors.accent : colors.hairline,
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted ? KisouTheme.tileShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical =
                    usesLargeText(context) || constraints.maxWidth < 300;
                final destination = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.regionName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.travelDateTime(
                        formatJpDate(departure),
                        _formatTime(departure),
                      ),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.softInk,
                      ),
                    ),
                  ],
                );
                final dDayChip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KisouTheme.gapM,
                    vertical: KisouTheme.gapXs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppStrings.travelDday(dDay),
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
                if (vertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      destination,
                      const SizedBox(height: KisouTheme.gapS),
                      dDayChip,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: destination),
                    const SizedBox(width: KisouTheme.gapM),
                    dDayChip,
                  ],
                );
              },
            ),
            if (status != null) ...[
              const SizedBox(height: KisouTheme.gapM),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    plan.syncState == TravelNotificationSyncState.scheduled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 18,
                    color: colors.softInk,
                  ),
                  const SizedBox(width: KisouTheme.gapS),
                  Expanded(
                    child: Text(
                      status,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.softInk,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (onOpenSettings != null) ...[
              const SizedBox(height: KisouTheme.gapXs),
              TextButton(
                onPressed: onOpenSettings,
                child: const Text(AppStrings.travelOpenNotificationSettings),
              ),
            ],
            const SizedBox(height: KisouTheme.gapS),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KisouTheme.gapXs,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(AppStrings.travelEdit),
                ),
                IconButton(
                  tooltip: AppStrings.travelDelete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? _notificationStatus(TravelPlan plan) {
  if (plan.reminder == TravelReminder.none) {
    return plan.syncState == TravelNotificationSyncState.pendingSchedule
        ? AppStrings.travelNotificationPending
        : null;
  }
  if (plan.reminderAtUtc?.isAfter(DateTime.now().toUtc()) != true) {
    return AppStrings.travelNotificationExpired;
  }
  return switch (plan.syncState) {
    TravelNotificationSyncState.scheduled =>
      AppStrings.travelNotificationScheduled,
    TravelNotificationSyncState.blockedPermission =>
      AppStrings.travelNotificationBlocked,
    TravelNotificationSyncState.pendingSchedule =>
      AppStrings.travelNotificationPending,
    _ => null,
  };
}

/// Opens the editor and persists the result before dismissing it.
///
/// [initialDate] and [initialCityCode] are used by the outlook result's
/// convenience action. They are only defaults; the user always confirms the
/// departure time and notification choice.
Future<TravelPlan?> showTravelPlanEditor({
  required BuildContext context,
  required WidgetRef ref,
  DateTime? initialDate,
  String? initialCityCode,
  TravelPlan? existing,
}) async {
  final saved = await showModalBottomSheet<TravelPlan>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _TravelPlanEditorSheet(
      initialDate: initialDate,
      initialCityCode: initialCityCode,
      existing: existing,
    ),
  );
  if (saved == null || !context.mounted) {
    return saved;
  }
  final successMessage = existing == null
      ? AppStrings.travelSaved
      : AppStrings.travelUpdated;
  final warning = switch (saved.syncState) {
    TravelNotificationSyncState.blockedPermission =>
      AppStrings.travelNotificationPermissionDenied,
    TravelNotificationSyncState.pendingSchedule =>
      AppStrings.travelNotificationPending,
    _ => null,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        warning == null ? successMessage : '$successMessage\n$warning',
      ),
      action: saved.syncState == TravelNotificationSyncState.blockedPermission
          ? SnackBarAction(
              label: AppStrings.travelOpenNotificationSettings,
              onPressed: () {
                ref
                    .read(travelPlanProvider.notifier)
                    .openNotificationSettings();
              },
            )
          : null,
    ),
  );
  return saved;
}

class _TravelPlanEditorSheet extends ConsumerStatefulWidget {
  const _TravelPlanEditorSheet({
    required this.initialDate,
    required this.initialCityCode,
    required this.existing,
  });

  final DateTime? initialDate;
  final String? initialCityCode;
  final TravelPlan? existing;

  @override
  ConsumerState<_TravelPlanEditorSheet> createState() =>
      _TravelPlanEditorSheetState();
}

class _TravelPlanEditorSheetState
    extends ConsumerState<_TravelPlanEditorSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  late String _cityCode;
  late TravelReminder _reminder;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existingDeparture = widget.existing?.departureOnJstClock;
    final requestedDate = existingDeparture ?? widget.initialDate;
    final today = jstToday();
    final defaultDeparture = nextTravelDepartureOnJstClock(DateTime.now());
    _date = requestedDate == null
        ? DateTime(
            defaultDeparture.year,
            defaultDeparture.month,
            defaultDeparture.day,
          )
        : requestedDate.isBefore(today)
        ? today
        : DateTime(requestedDate.year, requestedDate.month, requestedDate.day);
    _time = existingDeparture != null
        ? TimeOfDay(
            hour: existingDeparture.hour,
            minute: existingDeparture.minute,
          )
        : widget.initialDate == null
        ? TimeOfDay(
            hour: defaultDeparture.hour,
            minute: defaultDeparture.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    _cityCode =
        widget.existing?.cityCode ??
        (majorCityByCode(widget.initialCityCode ?? '')?.code) ??
        majorCities.first.code!;
    _reminder = widget.existing?.reminder ?? TravelReminder.none;
  }

  Future<void> _pickDate() async {
    final firstDate = jstToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(firstDate) ? firstDate : _date,
      firstDate: firstDate,
      lastDate: DateTime(firstDate.year + 2, firstDate.month, firstDate.day),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = TravelPlanDraft(
      cityCode: _cityCode,
      departureAtUtc: jstCivilDateTimeToUtc(
        date: _date,
        hour: _time.hour,
        minute: _time.minute,
      ),
      reminder: _reminder,
    );
    try {
      final controller = ref.read(travelPlanProvider.notifier);
      final saved = widget.existing == null
          ? await controller.create(
              draft,
              requestNotificationPermission: _reminder != TravelReminder.none,
            )
          : await controller.updatePlan(
              widget.existing!.id,
              draft,
              requestNotificationPermission: _reminder != TravelReminder.none,
            );
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } on DuplicateTravelPlanException {
      _showError(AppStrings.travelDuplicate);
    } on TravelPlanLimitException {
      _showError(AppStrings.travelLimitReached);
    } on TravelPlanValidationException catch (error) {
      _showError(
        error.code == 'reminder_not_future'
            ? AppStrings.travelReminderNotFuture
            : AppStrings.travelDepartureNotFuture,
      );
    } catch (_) {
      _showError(AppStrings.travelSaveFailed);
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _saving = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.kisou.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: KisouTheme.gapL),
            Text(
              widget.existing == null
                  ? AppStrings.travelAdd
                  : AppStrings.travelEdit,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: KisouTheme.gapL),
            DropdownButtonFormField<String>(
              initialValue: _cityCode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: AppStrings.travelPlaceLabel,
              ),
              items: [
                for (final city in majorCities)
                  DropdownMenuItem(
                    value: city.code,
                    child: Text(city.regionName),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _cityCode = value;
                          _error = null;
                        });
                      }
                    },
            ),
            const SizedBox(height: KisouTheme.gapM),
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical =
                    usesLargeText(context) || constraints.maxWidth < 320;
                final date = _EditorPicker(
                  label: AppStrings.travelDateLabel,
                  value: formatJpDate(_date),
                  icon: Icons.calendar_today_outlined,
                  onTap: _saving ? null : _pickDate,
                );
                final time = _EditorPicker(
                  label: AppStrings.travelTimeLabel,
                  value: _formatTimeOfDay(_time),
                  icon: Icons.schedule_outlined,
                  onTap: _saving ? null : _pickTime,
                );
                if (vertical) {
                  return Column(
                    children: [
                      date,
                      const SizedBox(height: KisouTheme.gapM),
                      time,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: date),
                    const SizedBox(width: KisouTheme.gapM),
                    Expanded(child: time),
                  ],
                );
              },
            ),
            const SizedBox(height: KisouTheme.gapM),
            DropdownButtonFormField<TravelReminder>(
              initialValue: _reminder,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: AppStrings.travelReminderLabel,
              ),
              items: [
                for (final reminder in TravelReminder.values)
                  DropdownMenuItem(
                    value: reminder,
                    child: Text(_reminderLabel(reminder)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _reminder = value;
                          _error = null;
                        });
                      }
                    },
            ),
            const SizedBox(height: KisouTheme.gapS),
            Text(
              AppStrings.travelJstNote,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk),
            ),
            if (_reminder != TravelReminder.none) ...[
              const SizedBox(height: KisouTheme.gapXs),
              Text(
                AppStrings.travelNotificationDelayNote,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: KisouTheme.gapM),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: KisouTheme.gapL),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.existing == null
                          ? AppStrings.travelSave
                          : AppStrings.travelUpdate,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPicker extends StatelessWidget {
  const _EditorPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      value: value,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KisouTheme.rSm),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(icon),
            enabled: onTap != null,
          ),
          child: Text(value),
        ),
      ),
    );
  }
}

String _reminderLabel(TravelReminder reminder) {
  return switch (reminder) {
    TravelReminder.none => AppStrings.travelReminderNone,
    TravelReminder.dayBefore => AppStrings.travelReminderDayBefore,
    TravelReminder.threeHoursBefore => AppStrings.travelReminderThreeHours,
  };
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
