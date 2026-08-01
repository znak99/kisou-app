import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_links.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/major_cities.dart';
import '../../models/location.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/ads_provider.dart';
import '../../providers/external_link_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_error.dart';
import '../../utils/geocode.dart';
import '../../widgets/error_state.dart';
import '../analysis/analysis_screen.dart';
import 'about_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfileAction {
  nickname,
  gender,
  location,
  sensitivity,
  reset,
  link,
  logout,
  delete,
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  var _isSaving = false;
  _ProfileAction? _savingAction;
  var _menuHasOverflow = false;
  var _menuScrollProgress = 1.0;
  var _waitingForLocationSettings = false;
  var _locationResumeInProgress = false;
  var _openingPrivacyPolicy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      final user = ref
          .read(userProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      if (user == null) {
        ref
            .read(userProvider.notifier)
            .getMe()
            .then<void>((_) {}, onError: (_) {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_waitingForLocationSettings ||
        _locationResumeInProgress) {
      return;
    }
    _waitingForLocationSettings = false;
    _locationResumeInProgress = true;
    Future.microtask(() async {
      try {
        await _useCurrentLocation();
      } finally {
        _locationResumeInProgress = false;
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
    return Column(
      children: [
        ExcludeSemantics(
          child: AnimatedOpacity(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            opacity: _menuHasOverflow ? 1 : 0,
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: _menuScrollProgress,
                backgroundColor: context.kisou.hairline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(
                  context.kisou.accent.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _updateMenuScrollProgress(notification.metrics);
              return false;
            },
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                _updateMenuScrollProgress(notification.metrics);
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  KisouTheme.pagePad,
                  KisouTheme.gapM,
                  KisouTheme.pagePad,
                  24,
                ),
                children: _profileSections(user),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _profileSections(User user) {
    final adsState = ref.watch(adsProvider);
    return [
      _ProfileHeader(user: user),
      const SizedBox(height: KisouTheme.gapL),
      // --- 個人情報設定 ---
      _CategorySection(
        title: AppStrings.profileCategoryPersonal,
        children: [
          _SettingRow(
            icon: Icons.person_outline,
            title: AppStrings.nicknameSetting,
            value: _displayValue(user.nickname),
            loading: _savingAction == _ProfileAction.nickname,
            onTap: _isSaving ? null : () => _editNickname(user),
          ),
          _SettingRow(
            icon: Icons.wc_outlined,
            title: AppStrings.genderSetting,
            value: _genderLabel(user.gender),
            loading: _savingAction == _ProfileAction.gender,
            onTap: _isSaving ? null : () => _editGender(user),
          ),
          _SettingRow(
            icon: Icons.location_on_outlined,
            title: AppStrings.locationSetting,
            value: _displayValue(user.regionName),
            loading: _savingAction == _ProfileAction.location,
            onTap: _isSaving ? null : () => _editLocation(),
          ),
        ],
      ),
      const SizedBox(height: KisouTheme.gapL),
      // --- 体感設定 ---
      _CategorySection(
        title: AppStrings.profileCategoryComfort,
        children: [
          _SettingRow(
            icon: Icons.insights_outlined,
            title: AppStrings.analysisTitle,
            value: AppStrings.analysisEntryDescription,
            onTap: _isSaving
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AnalysisScreen(),
                    ),
                  ),
          ),
          _SettingRow(
            icon: Icons.thermostat_outlined,
            title: AppStrings.sensitivitySetting,
            value:
                '${_coldSensitivityLabel(user.coldSensitivity)}'
                '${AppStrings.sensitivitySeparator}'
                '${_heatSensitivityLabel(user.heatSensitivity)}',
            loading: _savingAction == _ProfileAction.sensitivity,
            onTap: _isSaving ? null : () => _editSensitivity(user),
          ),
          _SettingRow(
            icon: Icons.restart_alt_rounded,
            title: AppStrings.dataReset,
            iconColor: context.kisou.warm,
            loading: _savingAction == _ProfileAction.reset,
            onTap: _isSaving ? null : _resetData,
          ),
        ],
      ),
      const SizedBox(height: KisouTheme.gapL),
      // --- 表示設定 ---
      const _SectionLabel(title: AppStrings.profileCategoryDisplay),
      const SizedBox(height: KisouTheme.gapS),
      _buildThemeSelector(),
      const SizedBox(height: KisouTheme.gapS),
      _TileCard(
        children: [
          _SettingRow(
            icon: Icons.notifications_none_outlined,
            title: AppStrings.pushSettings,
            value: AppStrings.pushSettingsDescription,
            onTap: _isSaving
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
          ),
        ],
      ),
      const SizedBox(height: KisouTheme.gapL),
      // --- アカウント設定 ---
      const _SectionLabel(title: AppStrings.profileCategoryAccount),
      const SizedBox(height: KisouTheme.gapS),
      _buildAccountLink(user),
      const SizedBox(height: KisouTheme.gapS),
      _TileCard(
        children: [
          if (!user.isAnonymous)
            _SettingRow(
              icon: Icons.logout,
              title: AppStrings.logout,
              loading: _savingAction == _ProfileAction.logout,
              onTap: _isSaving ? null : _confirmLogout,
            ),
          _SettingRow(
            icon: Icons.delete_outline,
            title: AppStrings.accountDelete,
            destructive: true,
            loading: _savingAction == _ProfileAction.delete,
            onTap: _isSaving ? null : _confirmDeleteAccount,
          ),
        ],
      ),
      const SizedBox(height: KisouTheme.gapL),
      // --- 法務・サポート ---
      const _SectionLabel(title: AppStrings.profileCategorySupport),
      const SizedBox(height: KisouTheme.gapS),
      _TileCard(
        children: [
          _SettingRow(
            icon: Icons.info_outline_rounded,
            title: AppStrings.aboutKisou,
            onTap: _isSaving
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutKisouScreen(),
                    ),
                  ),
          ),
          _SettingRow(
            icon: Icons.privacy_tip_outlined,
            title: AppStrings.privacyPolicy,
            loading: _openingPrivacyPolicy,
            onTap: _isSaving || _openingPrivacyPolicy
                ? null
                : _openPrivacyPolicy,
          ),
          if (adsState.privacyOptionsRequired)
            _SettingRow(
              icon: Icons.ads_click_outlined,
              title: AppStrings.adPrivacyOptions,
              loading: adsState.consentInProgress,
              onTap: _isSaving || adsState.consentInProgress
                  ? null
                  : _openAdPrivacyOptions,
            ),
        ],
      ),
    ];
  }

  Future<void> _openAdPrivacyOptions() async {
    await ref.read(adsProvider.notifier).showPrivacyOptions();
    if (!mounted || ref.read(adsProvider).error == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.adPrivacyOptionsFailed)),
    );
  }

  void _updateMenuScrollProgress(ScrollMetrics metrics) {
    final hasOverflow = metrics.maxScrollExtent > 0;
    final progress = !hasOverflow
        ? 1.0
        : (0.1 + 0.9 * (metrics.pixels / metrics.maxScrollExtent)).clamp(
            0.0,
            1.0,
          );
    if (hasOverflow == _menuHasOverflow &&
        (progress - _menuScrollProgress).abs() < 0.001) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _menuHasOverflow = hasOverflow;
        _menuScrollProgress = progress;
      });
    });
  }

  Widget _buildThemeSelector() {
    final mode = ref.watch(themeModeProvider);
    final largeText = usesLargeText(context);
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                size: 22,
                color: context.kisou.accent,
              ),
              const SizedBox(width: KisouTheme.gapM),
              // Matches _SettingRow's title styling so the display section
              // doesn't shout over the other settings rows.
              Text(
                AppStrings.themeSetting,
                style: TextStyle(
                  color: context.kisou.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: KisouTheme.gapM),
          SegmentedButton<ThemeMode>(
            direction: largeText ? Axis.vertical : Axis.horizontal,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
              textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              visualDensity: largeText
                  ? VisualDensity.standard
                  : VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(AppStrings.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(AppStrings.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(AppStrings.themeDark),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                ref.read(themeModeProvider.notifier).setMode(selection.first),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountLink(User user) {
    final c = context.kisou;
    if (!user.isAnonymous) {
      final label = user.authProvider == 'google'
          ? AppStrings.linkedWithGoogle
          : AppStrings.linkedWithApple;
      return ClayCard(
        child: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: c.accent, size: 22),
            const SizedBox(width: KisouTheme.gapM),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(Icons.check_circle_rounded, color: c.success, size: 22),
          ],
        ),
      );
    }
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: c.softInk, size: 20),
              const SizedBox(width: KisouTheme.gapS),
              Expanded(
                child: Text(
                  AppStrings.anonymousAccount,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: KisouTheme.gapXs),
          Text(
            AppStrings.anonymousAccountHelp,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.softInk),
          ),
          // Social account linking (Apple/Google) is intentionally hidden for
          // the anonymous-only MVP. The dev-only link stays for testing.
          if (ApiConfig.showDevelopmentLogin) ...[
            const SizedBox(height: KisouTheme.gapM),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(AppStrings.developerOptions),
              children: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => _linkAccount(
                          () => ref
                              .read(authProvider.notifier)
                              .linkWithDevelopment(),
                        ),
                  child: _savingAction == _ProfileAction.link
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('開発連携'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _linkAccount(Future<void> Function() action) async {
    _startSaving(_ProfileAction.link);
    try {
      await action();
      final updated = await ref.read(userProvider.notifier).getMe();
      _showMessage(
        updated.authProvider == 'google'
            ? AppStrings.linkedWithGoogle
            : AppStrings.linkedWithApple,
      );
    } catch (_) {
      _showMessage(AppStrings.linkFailed);
    } finally {
      if (mounted) {
        _stopSaving();
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await _confirm(
      title: AppStrings.dataResetTitle,
      message: AppStrings.dataResetConfirm,
      confirmLabel: AppStrings.dataResetAction,
      cancelLabel: AppStrings.cancel,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    _startSaving(_ProfileAction.reset);
    try {
      await ref.read(userProvider.notifier).resetData();
      _invalidateRecommendationData(includeFeedback: true);
      _showMessage(AppStrings.dataResetDone);
    } catch (_) {
      _showMessage(AppStrings.dataResetFailed);
    } finally {
      if (mounted) {
        _stopSaving();
      }
    }
  }

  Future<void> _loadUser() async {
    try {
      await ref.read(userProvider.notifier).getMe();
    } catch (_) {
      // The provider already holds the error rendered by _SettingsError.
    }
  }

  Future<void> _editNickname(User user) async {
    // Controller is owned here (not in the builder) so it can be disposed —
    // audit B17.
    final controller = TextEditingController(text: user.nickname);
    try {
      final nickname = await showDialog<String>(
        context: context,
        builder: (context) {
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
      if (nickname == null || nickname == user.nickname) {
        return;
      }
      // Enforce the same minimum length as onboarding (audit B15).
      if (nickname.length < 2) {
        _showMessage(AppStrings.nicknameMinLength);
        return;
      }
      await _updateUser(
        UserUpdate(nickname: nickname),
        action: _ProfileAction.nickname,
      );
    } finally {
      controller.dispose();
    }
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
    await _updateUser(
      UserUpdate(gender: gender),
      action: _ProfileAction.gender,
      recommendationChanged: true,
    );
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
              child: SingleChildScrollView(
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
      title: AppStrings.sensitivitySetting,
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
      action: _ProfileAction.sensitivity,
      recommendationChanged: true,
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
    if (action == _LocationAction.current) {
      await _useCurrentLocation();
      return;
    }
    final location = await _selectManualLocation();
    await _saveLocation(location);
  }

  Future<void> _useCurrentLocation() async {
    final location = await _requestCurrentLocation();
    await _saveLocation(location);
  }

  Future<void> _saveLocation(LocationValue? location) async {
    if (location == null) {
      return;
    }
    await _updateUser(
      UserUpdate(
        latitude: location.latitude,
        longitude: location.longitude,
        regionName: location.regionName,
      ),
      action: _ProfileAction.location,
      recommendationChanged: true,
    );
  }

  Future<LocationValue?> _requestCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showLocationRecovery(
          title: AppStrings.locationDisabled,
          actionLabel: AppStrings.openLocationServices,
          openSettings: Geolocator.openLocationSettings,
        );
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _showLocationRecovery(
          title: permission == LocationPermission.deniedForever
              ? AppStrings.locationDeniedForever
              : AppStrings.locationDenied,
          actionLabel: AppStrings.openAppSettings,
          openSettings: Geolocator.openAppSettings,
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final geocoded = await reverseGeocodeLocation(
        position.latitude,
        position.longitude,
      );
      final countryCode = geocoded?.countryCode?.trim();
      if (!isUsableJapanLocation(geocoded)) {
        _showMessage(
          geocoded == null ||
                  countryCode == null ||
                  countryCode.isEmpty ||
                  geocoded.regionName?.trim().isEmpty != false
              ? AppStrings.locationUnavailable
              : AppStrings.locationOutsideJapan,
        );
        return _selectManualLocation();
      }
      final region = geocoded!.regionName!;
      return LocationValue(
        latitude: position.latitude,
        longitude: position.longitude,
        regionName: region,
      );
    } catch (_) {
      _showMessage(AppStrings.locationUnavailable);
      return _selectManualLocation();
    }
  }

  Future<void> _showLocationRecovery({
    required String title,
    required String actionLabel,
    required Future<bool> Function() openSettings,
  }) async {
    if (!mounted) {
      return;
    }
    final action = await showModalBottomSheet<_LocationRecoveryAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: KisouTheme.gapL),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_LocationRecoveryAction.settings),
                child: Text(actionLabel),
              ),
              const SizedBox(height: KisouTheme.gapS),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_LocationRecoveryAction.manual),
                child: const Text(AppStrings.manualLocationOption),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == _LocationRecoveryAction.manual) {
      await _saveLocation(await _selectManualLocation());
      return;
    }
    if (action == _LocationRecoveryAction.settings) {
      _waitingForLocationSettings = true;
      final opened = await openSettings();
      if (!opened) {
        _waitingForLocationSettings = false;
        _showMessage(AppStrings.useCurrentLocationFailed);
      }
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
    if (_openingPrivacyPolicy) {
      return;
    }
    setState(() => _openingPrivacyPolicy = true);
    var opened = false;
    try {
      opened = await ref.read(externalUrlLauncherProvider)(
        AppLinks.privacyPolicy,
      );
    } catch (_) {
      // Fall through to the same user-facing failure message as a false result.
    } finally {
      if (mounted) {
        setState(() => _openingPrivacyPolicy = false);
      }
    }
    if (!opened && mounted) {
      _showMessage(AppStrings.privacyPolicyOpenFailed);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await _confirm(
      title: AppStrings.logoutConfirm,
      message: AppStrings.logoutConfirmBody,
      confirmLabel: AppStrings.logoutAction,
      cancelLabel: AppStrings.cancel,
    );
    if (!confirmed) {
      return;
    }
    _startSaving(_ProfileAction.logout);
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      if (mounted) {
        _showMessage(AppStrings.logoutFailed);
      }
    } finally {
      if (mounted) {
        _stopSaving();
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await _confirm(
      title: AppStrings.accountDeleteTitle,
      message: AppStrings.accountDeleteConfirm,
      confirmLabel: AppStrings.deleteAction,
      cancelLabel: AppStrings.cancel,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    _startSaving(_ProfileAction.delete);
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (error) {
      _showMessage(
        error is LocalAccountCleanupException
            ? AppStrings.accountDeleteLocalCleanupFailed
            : classifyApiError(error) == ApiErrorKind.unknown
            ? AppStrings.deleteFailed
            : apiErrorMessage(error),
      );
    } finally {
      if (mounted) {
        _stopSaving();
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
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
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

  Future<void> _updateUser(
    UserUpdate update, {
    required _ProfileAction action,
    bool recommendationChanged = false,
  }) async {
    _startSaving(action);
    try {
      await ref.read(userProvider.notifier).updateMe(update);
      if (recommendationChanged) {
        _invalidateRecommendationData();
      }
    } catch (error) {
      _showMessage(
        classifyApiError(error) == ApiErrorKind.unknown
            ? AppStrings.updateFailed
            : apiErrorMessage(error),
      );
    } finally {
      if (mounted) {
        _stopSaving();
      }
    }
  }

  void _startSaving(_ProfileAction action) {
    setState(() {
      _isSaving = true;
      _savingAction = action;
    });
  }

  void _stopSaving() {
    setState(() {
      _isSaving = false;
      _savingAction = null;
    });
  }

  void _invalidateRecommendationData({bool includeFeedback = false}) {
    ref.invalidate(homeProvider);
    ref.invalidate(forecastTomorrowProvider);
    ref.invalidate(forecastOutlookProvider);
    ref.invalidate(analysisProvider);
    if (includeFeedback) {
      ref.invalidate(feedbackProvider);
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final nickname = user.nickname.trim();
    final region = user.regionName?.trim() ?? '';
    return ClayCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KisouTheme.rMd),
            child: Image.asset(
              'assets/brand/default_avatar.png',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: KisouTheme.gapL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname.isEmpty ? AppStrings.appName : nickname,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (region.isNotEmpty) ...[
                  const SizedBox(height: KisouTheme.gapXs),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 15, color: c.softInk),
                      const SizedBox(width: KisouTheme.gapXs),
                      Expanded(
                        child: Text(
                          region,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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

/// A titled group: a section label followed by a card of setting rows.
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: title),
        const SizedBox(height: KisouTheme.gapS),
        _TileCard(children: children),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: KisouTheme.gapXs),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.kisou.softInk,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A grouped card containing setting rows separated by hairline dividers.
class _TileCard extends StatelessWidget {
  const _TileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(height: 1, thickness: 1, color: c.hairline, indent: 50),
        );
      }
      rows.add(children[i]);
    }
    return ClayCard(
      padding: EdgeInsets.zero,
      radius: KisouTheme.rLg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KisouTheme.rLg - 1),
        child: Column(children: rows),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.destructive = false,
    this.iconColor,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final String? value;
  final bool destructive;
  final Color? iconColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final disabled = onTap == null;
    final titleColor = destructive
        ? Theme.of(context).colorScheme.error
        : c.ink;
    final resolvedIconColor = destructive
        ? Theme.of(context).colorScheme.error
        : (iconColor ?? c.accent);
    return Semantics(
      button: true,
      enabled: !disabled,
      label: title,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KisouTheme.gapL,
                vertical: KisouTheme.gapM,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: disabled ? c.softInk : resolvedIconColor,
                  ),
                  const SizedBox(width: KisouTheme.gapM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (value != null && value!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            value!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.chevron_right, size: 20, color: c.softInk),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final largeText = usesLargeText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          direction: largeText ? Axis.vertical : Axis.horizontal,
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

enum _LocationAction { current, manual }

enum _LocationRecoveryAction { settings, manual }
