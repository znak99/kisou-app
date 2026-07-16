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
  });

  final LocationValue? selectedLocation;
  final ValueChanged<LocationValue> onLocationSelected;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  bool _isLoading = false;
  String? _message;
  bool _showManualList = false;

  Future<void> _requestCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showManualSelection(AppStrings.locationDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showManualSelection(AppStrings.locationDenied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final region = await reverseGeocodeRegion(
        position.latitude,
        position.longitude,
      );
      widget.onLocationSelected(
        LocationValue(
          latitude: position.latitude,
          longitude: position.longitude,
          regionName: region ?? AppStrings.currentLocation,
        ),
      );
    } catch (_) {
      _showManualSelection(AppStrings.locationDenied);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showManualSelection(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _message = message;
      _showManualList = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    final selectedLocation = widget.selectedLocation;
    return Padding(
      padding: const EdgeInsets.all(KisouTheme.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: KisouTheme.gapXl),
          const _StepHeader(
            icon: Icons.place_rounded,
            title: AppStrings.locationPrompt,
          ),
          const SizedBox(height: KisouTheme.gapXl),
          FilledButton.icon(
            onPressed: _isLoading ? null : _requestCurrentLocation,
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 20),
            label: const Text(AppStrings.allowLocation),
          ),
          const SizedBox(height: KisouTheme.gapM),
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () => setState(() => _showManualList = true),
            icon: const Icon(Icons.map_rounded, size: 20),
            label: const Text(AppStrings.manualLocation),
          ),
          if (_message != null) ...[
            const SizedBox(height: KisouTheme.gapL),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: c.softInk),
                const SizedBox(width: KisouTheme.gapXs),
                Expanded(
                  child: Text(
                    _message!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
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
          ],
          const SizedBox(height: KisouTheme.gapL),
          if (_showManualList) ...[
            Row(
              children: [
                Icon(Icons.list_rounded, size: 20, color: c.accent),
                const SizedBox(width: KisouTheme.gapS),
                Text(
                  AppStrings.selectRegion,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: KisouTheme.gapS),
            Expanded(
              child: ListView.separated(
                itemCount: majorCities.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final city = majorCities[index];
                  final isSelected =
                      city.regionName == selectedLocation?.regionName;
                  return ListTile(
                    leading: Icon(
                      Icons.location_city_rounded,
                      size: 20,
                      color: isSelected ? c.accent : c.softInk,
                    ),
                    title: Text(city.regionName),
                    selected: isSelected,
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, size: 20, color: c.accent)
                        : null,
                    onTap: () => widget.onLocationSelected(city),
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
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
