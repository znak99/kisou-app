import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/location.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/error_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static final _privacyPolicyUri = Uri.parse('https://example.com/privacy');

  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref
          .read(userProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      if (user == null) {
        ref.read(userProvider.notifier).getMe();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    return SafeArea(
      bottom: false,
      child: userState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildProfile(user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SettingsError(error: error, onRetry: _loadUser),
      ),
    );
  }

  Widget _buildProfile(User user) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          AppStrings.tabProfile,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _ProfileHeader(user: user),
        const SizedBox(height: 20),
        if (_isSaving) const LinearProgressIndicator(),
        _SettingsTile(
          icon: Icons.person_outline,
          title: AppStrings.nicknameSetting,
          value: _displayValue(user.nickname),
          onTap: _isSaving ? null : () => _editNickname(user),
        ),
        _SettingsTile(
          icon: Icons.wc_outlined,
          title: AppStrings.genderSetting,
          value: _genderLabel(user.gender),
          onTap: _isSaving ? null : () => _editGender(user),
        ),
        _SettingsTile(
          icon: Icons.thermostat_outlined,
          title: AppStrings.sensitivitySetting,
          value:
              '${_coldSensitivityLabel(user.coldSensitivity)}'
              '${AppStrings.sensitivitySeparator}'
              '${_heatSensitivityLabel(user.heatSensitivity)}',
          onTap: _isSaving ? null : () => _editSensitivity(user),
        ),
        _SettingsTile(
          icon: Icons.schedule_outlined,
          title: AppStrings.timeSetting,
          value:
              '${_displayTime(user.departureTime)}'
              '${AppStrings.timeRangeSeparator}'
              '${_displayTime(user.returnTime)}',
          onTap: _isSaving ? null : () => _editTime(user),
        ),
        _SettingsTile(
          icon: Icons.location_on_outlined,
          title: AppStrings.locationSetting,
          value: _displayValue(user.regionName),
          onTap: _isSaving ? null : () => _editLocation(),
        ),
        const Divider(height: 28),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: AppStrings.privacyPolicy,
          value: null,
          onTap: _isSaving ? null : _openPrivacyPolicy,
        ),
        _SettingsTile(
          icon: Icons.logout,
          title: AppStrings.logout,
          value: null,
          onTap: _isSaving ? null : _confirmLogout,
        ),
        _SettingsTile(
          icon: Icons.delete_outline,
          title: AppStrings.accountDelete,
          value: null,
          destructive: true,
          onTap: _isSaving ? null : _confirmDeleteAccount,
        ),
      ],
    );
  }

  Future<void> _loadUser() async {
    await ref.read(userProvider.notifier).getMe();
  }

  Future<void> _editNickname(User user) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: user.nickname);
        return AlertDialog(
          title: const Text(AppStrings.editNickname),
          content: TextField(
            controller: controller,
            maxLength: 10,
            autofocus: true,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
            decoration: const InputDecoration(
              hintText: AppStrings.nicknameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text(AppStrings.save),
            ),
          ],
        );
      },
    );
    if (nickname == null || nickname.isEmpty || nickname == user.nickname) {
      return;
    }
    await _updateUser(UserUpdate(nickname: nickname));
  }

  Future<void> _editGender(User user) async {
    final gender = await _showChoiceSheet(
      title: AppStrings.genderSetting,
      currentValue: user.gender,
      options: const [
        _ChoiceOption(value: 'male', label: AppStrings.male),
        _ChoiceOption(value: 'female', label: AppStrings.female),
        _ChoiceOption(value: 'unspecified', label: AppStrings.unspecified),
      ],
    );
    if (gender == null || gender == user.gender) {
      return;
    }
    await _updateUser(UserUpdate(gender: gender));
  }

  Future<void> _editSensitivity(User user) async {
    final selection = await showModalBottomSheet<_SensitivitySelection>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var cold = user.coldSensitivity;
        var heat = user.heatSensitivity;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.sensitivitySetting,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _ChoiceGroup(
                      title: AppStrings.coldQuestion,
                      currentValue: cold,
                      options: const [
                        _ChoiceOption(
                          value: 'high',
                          label: AppStrings.coldHigh,
                        ),
                        _ChoiceOption(
                          value: 'normal',
                          label: AppStrings.normal,
                        ),
                        _ChoiceOption(value: 'low', label: AppStrings.coldLow),
                      ],
                      onSelected: (value) => setSheetState(() => cold = value),
                    ),
                    const SizedBox(height: 16),
                    _ChoiceGroup(
                      title: AppStrings.heatQuestion,
                      currentValue: heat,
                      options: const [
                        _ChoiceOption(
                          value: 'high',
                          label: AppStrings.heatHigh,
                        ),
                        _ChoiceOption(
                          value: 'normal',
                          label: AppStrings.normal,
                        ),
                        _ChoiceOption(value: 'low', label: AppStrings.heatLow),
                      ],
                      onSelected: (value) => setSheetState(() => heat = value),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_SensitivitySelection(cold: cold, heat: heat)),
                      child: const Text(AppStrings.save),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selection == null ||
        (selection.cold == user.coldSensitivity &&
            selection.heat == user.heatSensitivity)) {
      return;
    }
    final confirmed = await _confirm(
      message: AppStrings.sensitivityResetConfirm,
      confirmLabel: AppStrings.yes,
      cancelLabel: AppStrings.no,
    );
    if (!confirmed) {
      return;
    }
    await _updateUser(
      UserUpdate(
        coldSensitivity: selection.cold,
        heatSensitivity: selection.heat,
      ),
    );
  }

  Future<void> _editTime(User user) async {
    final selection = await showDialog<_TimeSelection>(
      context: context,
      builder: (context) {
        var departure = _parseTime(user.departureTime);
        var returning = _parseTime(user.returnTime);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(AppStrings.timeSetting),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimePickerTile(
                    label: AppStrings.departureTime,
                    time: departure,
                    onTap: () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: departure,
                      );
                      if (selected != null) {
                        setDialogState(() => departure = selected);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _TimePickerTile(
                    label: AppStrings.returnTime,
                    time: returning,
                    onTap: () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: returning,
                      );
                      if (selected != null) {
                        setDialogState(() => returning = selected);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _TimeSelection(departure: departure, returning: returning),
                  ),
                  child: const Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );
    if (selection == null) {
      return;
    }
    final departureTime = _formatTime(selection.departure);
    final returnTime = _formatTime(selection.returning);
    if (departureTime == _displayTime(user.departureTime) &&
        returnTime == _displayTime(user.returnTime)) {
      return;
    }
    await _updateUser(
      UserUpdate(departureTime: departureTime, returnTime: returnTime),
    );
  }

  Future<void> _editLocation() async {
    final action = await showModalBottomSheet<_LocationAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text(AppStrings.currentLocationOption),
                onTap: () => Navigator.of(context).pop(_LocationAction.current),
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text(AppStrings.manualLocationOption),
                onTap: () => Navigator.of(context).pop(_LocationAction.manual),
              ),
            ],
          ),
        );
      },
    );
    if (action == null) {
      return;
    }
    final location = action == _LocationAction.current
        ? await _requestCurrentLocation()
        : await _selectManualLocation();
    if (location == null) {
      return;
    }
    await _updateUser(
      UserUpdate(
        latitude: location.latitude,
        longitude: location.longitude,
        regionName: location.regionName,
      ),
    );
  }

  Future<LocationValue?> _requestCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage(AppStrings.useCurrentLocationFailed);
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(AppStrings.useCurrentLocationFailed);
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      return LocationValue(
        latitude: position.latitude,
        longitude: position.longitude,
        regionName: AppStrings.currentLocation,
      );
    } catch (_) {
      _showMessage(AppStrings.useCurrentLocationFailed);
      return null;
    }
  }

  Future<LocationValue?> _selectManualLocation() {
    return showModalBottomSheet<LocationValue>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: ListView.separated(
              itemCount: majorCities.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final city = majorCities[index];
                return ListTile(
                  title: Text(city.regionName),
                  onTap: () => Navigator.of(context).pop(city),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      _privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _showMessage(AppStrings.privacyPolicyOpenFailed);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await _confirm(
      message: AppStrings.logoutConfirm,
      confirmLabel: AppStrings.yes,
      cancelLabel: AppStrings.no,
    );
    if (!confirmed) {
      return;
    }
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await _confirm(
      message: AppStrings.accountDeleteConfirm,
      confirmLabel: AppStrings.deleteAction,
      cancelLabel: AppStrings.cancel,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(userProvider.notifier).deleteMe();
      await ref.read(authProvider.notifier).logout();
    } catch (error) {
      _showMessage(
        classifyApiError(error) == ApiErrorKind.unknown
            ? AppStrings.deleteFailed
            : apiErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String?> _showChoiceSheet({
    required String title,
    required String currentValue,
    required List<_ChoiceOption> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option.label),
                  trailing: option.value == currentValue
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirm({
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _updateUser(UserUpdate update) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(userProvider.notifier).updateMe(update);
    } catch (error) {
      _showMessage(
        classifyApiError(error) == ApiErrorKind.unknown
            ? AppStrings.updateFailed
            : apiErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayValue(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? AppStrings.notSet : trimmed;
  }

  String _genderLabel(String value) {
    return switch (value) {
      'male' => AppStrings.male,
      'female' => AppStrings.female,
      _ => AppStrings.unspecified,
    };
  }

  String _coldSensitivityLabel(String value) {
    return switch (value) {
      'high' => AppStrings.coldHigh,
      'low' => AppStrings.coldLow,
      _ => AppStrings.normal,
    };
  }

  String _heatSensitivityLabel(String value) {
    return switch (value) {
      'high' => AppStrings.heatHigh,
      'low' => AppStrings.heatLow,
      _ => AppStrings.normal,
    };
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _displayTime(String value) {
    return _formatTime(_parseTime(value));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final nickname = user.nickname.trim();
    final region = user.regionName?.trim() ?? '';
    return ClayCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: KisouTheme.deepSky.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const BrandLogo(variant: BrandLogoVariant.mark, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname.isEmpty ? AppStrings.appName : nickname,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (region.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 15,
                        color: KisouTheme.softInk,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        region,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: value == null ? null : Text(value!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      message: apiErrorMessage(error),
      actionLabel: AppStrings.retry,
      onAction: onRetry,
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.currentValue,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final String currentValue;
  final List<_ChoiceOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final option in options)
              ButtonSegment<String>(
                value: option.value,
                label: Text(option.label),
              ),
          ],
          selected: {currentValue},
          onSelectionChanged: (values) => onSelected(values.first),
        ),
      ],
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text('$hour:$minute'),
      onTap: onTap,
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _SensitivitySelection {
  const _SensitivitySelection({required this.cold, required this.heat});

  final String cold;
  final String heat;
}

class _TimeSelection {
  const _TimeSelection({required this.departure, required this.returning});

  final TimeOfDay departure;
  final TimeOfDay returning;
}

enum _LocationAction { current, manual }
