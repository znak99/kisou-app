import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../config/theme.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/major_cities.dart';
import '../../../models/location.dart';
import '../../../utils/geocode.dart';

class LocationStep extends StatefulWidget {
  const LocationStep({
    super.key,
    required this.selectedLocation,
    required this.onLocationSelected,
    required this.onComplete,
    required this.isSaving,
  });

  final LocationValue? selectedLocation;
  final ValueChanged<LocationValue> onLocationSelected;
  final VoidCallback onComplete;
  final bool isSaving;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

enum _LocationIssue {
  none,
  serviceDisabled,
  denied,
  deniedForever,
  outsideJapan,
  unavailable,
}

class _LocationStepState extends State<LocationStep> {
  bool _isLoading = false;
  _LocationIssue _issue = _LocationIssue.none;

  Future<void> _requestCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _issue = _LocationIssue.none;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setIssue(_LocationIssue.serviceDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _setIssue(_LocationIssue.deniedForever);
        return;
      }
      if (permission == LocationPermission.denied) {
        _setIssue(_LocationIssue.denied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final geocoded = await reverseGeocodeLocation(
        position.latitude,
        position.longitude,
      );
      if (!mounted) {
        return;
      }

      if (geocoded == null) {
        _setIssue(_LocationIssue.unavailable);
        await _forceManualSelection();
        return;
      }
      if (!geocoded.isJapan) {
        _setIssue(_LocationIssue.outsideJapan);
        await _forceManualSelection();
        return;
      }
      final regionName = geocoded.regionName;
      if (regionName == null || regionName.isEmpty) {
        _setIssue(_LocationIssue.unavailable);
        await _forceManualSelection();
        return;
      }
      widget.onLocationSelected(
        LocationValue(
          latitude: position.latitude,
          longitude: position.longitude,
          regionName: regionName,
        ),
      );
    } catch (_) {
      _setIssue(_LocationIssue.unavailable);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setIssue(_LocationIssue issue) {
    if (!mounted) {
      return;
    }
    setState(() {
      _issue = issue;
      _isLoading = false;
    });
  }

  Future<void> _forceManualSelection() async {
    final location = await _selectManualLocation();
    if (location != null && mounted) {
      widget.onLocationSelected(location);
    }
  }

  Future<void> _chooseManualLocation() async {
    final location = await _selectManualLocation();
    if (location != null && mounted) {
      setState(() => _issue = _LocationIssue.none);
      widget.onLocationSelected(location);
    }
  }

  Future<LocationValue?> _selectManualLocation() {
    return showModalBottomSheet<LocationValue>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    AppStrings.selectRegion,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: majorCities.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final city = majorCities[index];
                      final selected =
                          city.regionName ==
                          widget.selectedLocation?.regionName;
                      return ListTile(
                        minTileHeight: 56,
                        leading: const Icon(Icons.location_city_rounded),
                        title: Text(city.regionName),
                        selected: selected,
                        trailing: selected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.of(context).pop(city),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? get _issueMessage {
    return switch (_issue) {
      _LocationIssue.none => null,
      _LocationIssue.serviceDisabled => AppStrings.locationDisabled,
      _LocationIssue.denied => AppStrings.locationDenied,
      _LocationIssue.deniedForever => AppStrings.locationDeniedForever,
      _LocationIssue.outsideJapan => AppStrings.locationOutsideJapan,
      _LocationIssue.unavailable => AppStrings.locationUnavailable,
    };
  }

  Future<void> _openSettings() async {
    if (_issue == _LocationIssue.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final selectedLocation = widget.selectedLocation;
    final busy = _isLoading || widget.isSaving;
    final showSettings =
        _issue == _LocationIssue.serviceDisabled ||
        _issue == _LocationIssue.deniedForever;

    return ListView(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      children: [
        const SizedBox(height: KisouTheme.gapXl),
        const _StepHeader(
          icon: Icons.place_rounded,
          title: AppStrings.locationPrompt,
        ),
        const SizedBox(height: KisouTheme.gapS),
        Text(
          AppStrings.locationHelp,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: c.softInk),
        ),
        const SizedBox(height: KisouTheme.gapXl),
        FilledButton.icon(
          onPressed: busy ? null : _requestCurrentLocation,
          icon: _isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, size: 20),
          label: Text(
            _issue == _LocationIssue.denied
                ? AppStrings.retryLocation
                : AppStrings.allowLocation,
          ),
        ),
        const SizedBox(height: KisouTheme.gapM),
        OutlinedButton.icon(
          onPressed: busy ? null : _chooseManualLocation,
          icon: const Icon(Icons.map_rounded, size: 20),
          label: const Text(AppStrings.manualLocation),
        ),
        if (_issueMessage case final message?) ...[
          const SizedBox(height: KisouTheme.gapL),
          Semantics(
            liveRegion: true,
            child: ClayCard(
              padding: const EdgeInsets.all(KisouTheme.gapM),
              radius: KisouTheme.rSm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: c.softInk,
                      ),
                      const SizedBox(width: KisouTheme.gapS),
                      Expanded(
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (showSettings) ...[
                    const SizedBox(height: KisouTheme.gapS),
                    TextButton(
                      onPressed: _openSettings,
                      child: const Text(AppStrings.openDeviceSettings),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (selectedLocation != null) ...[
          const SizedBox(height: KisouTheme.gapL),
          ClayCard(
            padding: const EdgeInsets.symmetric(
              horizontal: KisouTheme.gapL,
              vertical: KisouTheme.gapM,
            ),
            radius: KisouTheme.rSm,
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 20, color: c.accent),
                const SizedBox(width: KisouTheme.gapM),
                Expanded(
                  child: Text(
                    selectedLocation.regionName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KisouTheme.gapXl),
          FilledButton(
            onPressed: busy ? null : widget.onComplete,
            child: widget.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.finishOnboarding),
          ),
        ],
        const SizedBox(height: KisouTheme.gapXl),
      ],
    );
  }
}

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
