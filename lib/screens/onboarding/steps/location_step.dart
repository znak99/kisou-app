import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../constants/app_strings.dart';
import '../../../constants/major_cities.dart';
import '../../../models/location.dart';

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

      final position = await Geolocator.getCurrentPosition();
      widget.onLocationSelected(
        LocationValue(
          latitude: position.latitude,
          longitude: position.longitude,
          regionName: AppStrings.currentLocation,
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
    final selectedLocation = widget.selectedLocation;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            AppStrings.locationPrompt,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _requestCurrentLocation,
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.allowLocation),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _showManualList = true),
            child: const Text(AppStrings.manualLocation),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (selectedLocation != null) ...[
            const SizedBox(height: 16),
            Text(
              selectedLocation.regionName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 24),
          if (_showManualList) ...[
            Text(
              AppStrings.selectRegion,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: majorCities.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final city = majorCities[index];
                  return ListTile(
                    title: Text(city.regionName),
                    selected: city.regionName == selectedLocation?.regionName,
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
