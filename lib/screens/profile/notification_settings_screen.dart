import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/push_notification.dart';
import '../../providers/push_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pushSettingsProvider);
    return Scaffold(
      backgroundColor: context.kisou.bg,
      appBar: AppBar(title: const Text(AppStrings.pushSettings)),
      body: SafeArea(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(
            onRetry: () =>
                unawaited(ref.read(pushSettingsProvider.notifier).retry()),
          ),
          data: (state) => state.available
              ? _SettingsBody(state: state)
              : const _UnavailableBody(),
        ),
      ),
    );
  }
}

class _UnavailableBody extends ConsumerWidget {
  const _UnavailableBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      child: ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 36,
              color: context.kisou.softInk,
            ),
            const SizedBox(height: KisouTheme.gapM),
            Text(
              AppStrings.pushUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: KisouTheme.gapS),
            Text(
              AppStrings.pushUnavailableBody,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.kisou.softInk),
            ),
            const SizedBox(height: KisouTheme.gapM),
            FilledButton.tonal(
              onPressed: () =>
                  unawaited(ref.read(pushSettingsProvider.notifier).retry()),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.state});

  final PushSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pushSettingsProvider.notifier);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            KisouTheme.pagePad,
            KisouTheme.gapM,
            KisouTheme.pagePad,
            32,
          ),
          children: [
            Text(
              AppStrings.pushSettingsIntro,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.kisou.softInk),
            ),
            if (state.permission != PushPermissionState.allowed) ...[
              const SizedBox(height: KisouTheme.gapM),
              _PermissionCard(state: state),
            ],
            if (state.error != null) ...[
              const SizedBox(height: KisouTheme.gapM),
              _ErrorCard(error: state.error!),
            ],
            const SizedBox(height: KisouTheme.gapL),
            _DailyNotificationCard(
              icon: Icons.wb_sunny_outlined,
              title: AppStrings.pushMorningTitle,
              description: AppStrings.pushMorningDescription,
              enabled: state.preferences.morningEnabled,
              time: state.preferences.morningTime,
              busy: state.isSaving,
              onEnabledChanged: controller.setMorningEnabled,
              onTimeChanged: controller.setMorningTime,
            ),
            const SizedBox(height: KisouTheme.gapM),
            _DailyNotificationCard(
              icon: Icons.nights_stay_outlined,
              title: AppStrings.pushEveningTitle,
              description: AppStrings.pushEveningDescription,
              enabled: state.preferences.eveningEnabled,
              time: state.preferences.eveningTime,
              busy: state.isSaving,
              onEnabledChanged: controller.setEveningEnabled,
              onTimeChanged: controller.setEveningTime,
            ),
            if (state.permission == PushPermissionState.allowed) ...[
              const SizedBox(height: KisouTheme.gapM),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: context.kisou.success,
                    ),
                    const SizedBox(width: KisouTheme.gapS),
                    Expanded(
                      child: Text(
                        AppStrings.pushPermissionAllowed,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.kisou.softInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (state.isSaving)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard({required this.state});

  final PushSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (state.permission) {
      PushPermissionState.blocked => AppStrings.pushPermissionBlocked,
      PushPermissionState.denied => AppStrings.pushPermissionDenied,
      _ => AppStrings.pushPermissionNotDetermined,
    };
    final controller = ref.read(pushSettingsProvider.notifier);
    final mayRequest =
        state.preferences.anyEnabled &&
        state.permission != PushPermissionState.blocked;
    return Semantics(
      liveRegion: true,
      child: ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: context.kisou.warm,
                ),
                const SizedBox(width: KisouTheme.gapS),
                Expanded(child: Text(message)),
              ],
            ),
            const SizedBox(height: KisouTheme.gapM),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: KisouTheme.gapS,
              runSpacing: KisouTheme.gapS,
              children: [
                if (mayRequest)
                  FilledButton.tonal(
                    onPressed: state.isSaving
                        ? null
                        : () =>
                              unawaited(controller.requestPermissionAndSync()),
                    child: const Text(AppStrings.pushPermissionRequest),
                  ),
                OutlinedButton(
                  onPressed: state.isSaving
                      ? null
                      : () async {
                          final opened = await controller.openAppSettings();
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  AppStrings.pushSettingsOpenFailed,
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text(AppStrings.pushOpenDeviceSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends ConsumerWidget {
  const _ErrorCard({required this.error});

  final PushSettingsError error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      PushSettingsError.save => AppStrings.pushSaveFailed,
      PushSettingsError.registration => AppStrings.pushRegistrationFailed,
      PushSettingsError.permission => AppStrings.pushPermissionFailed,
      PushSettingsError.settings => AppStrings.pushSettingsOpenFailed,
    };
    return Semantics(
      liveRegion: true,
      child: ClayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: KisouTheme.gapS),
                Expanded(child: Text(message)),
              ],
            ),
            const SizedBox(height: KisouTheme.gapS),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    unawaited(ref.read(pushSettingsProvider.notifier).retry()),
                child: const Text(AppStrings.retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyNotificationCard extends StatelessWidget {
  const _DailyNotificationCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.time,
    required this.busy,
    required this.onEnabledChanged,
    required this.onTimeChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final NotificationTime time;
  final bool busy;
  final Future<void> Function(bool value) onEnabledChanged;
  final Future<void> Function(NotificationTime value) onTimeChanged;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            secondary: Icon(icon, color: context.kisou.accent),
            title: Text(title),
            subtitle: Text(description),
            value: enabled,
            onChanged: busy
                ? null
                : (value) => unawaited(onEnabledChanged(value)),
          ),
          Divider(height: 1, color: context.kisou.hairline),
          Semantics(
            button: true,
            label:
                '${AppStrings.pushTimeLabel}、${time.apiValue}、'
                '${AppStrings.pushJst}',
            child: InkWell(
              onTap: busy ? null : () => _pickTime(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: KisouTheme.gapM,
                    runSpacing: KisouTheme.gapXs,
                    children: [
                      const Text(AppStrings.pushTimeLabel),
                      Text(
                        '${time.apiValue}  ${AppStrings.pushJst}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: AppStrings.pushTimeLabel,
      cancelText: AppStrings.cancel,
      confirmText: AppStrings.save,
    );
    if (selected == null) {
      return;
    }
    await onTimeChanged(
      NotificationTime(hour: selected.hour, minute: selected.minute),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KisouTheme.pagePad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.dataFetchFailed),
            const SizedBox(height: KisouTheme.gapM),
            FilledButton(
              onPressed: onRetry,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
