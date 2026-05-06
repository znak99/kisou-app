import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../constants/app_strings.dart';

class LocationValue {
  const LocationValue({
    required this.latitude,
    required this.longitude,
    required this.regionName,
  });

  final double latitude;
  final double longitude;
  final String regionName;
}

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
                itemCount: _majorCities.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final city = _majorCities[index];
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

const _majorCities = [
  LocationValue(latitude: 35.6812, longitude: 139.7671, regionName: '東京'),
  LocationValue(latitude: 34.6937, longitude: 135.5023, regionName: '大阪'),
  LocationValue(latitude: 35.1815, longitude: 136.9066, regionName: '名古屋'),
  LocationValue(latitude: 33.5904, longitude: 130.4017, regionName: '福岡'),
  LocationValue(latitude: 43.0618, longitude: 141.3545, regionName: '札幌'),
  LocationValue(latitude: 38.2682, longitude: 140.8694, regionName: '仙台'),
  LocationValue(latitude: 35.4437, longitude: 139.6380, regionName: '横浜'),
  LocationValue(latitude: 35.0116, longitude: 135.7681, regionName: '京都'),
  LocationValue(latitude: 34.3853, longitude: 132.4553, regionName: '広島'),
  LocationValue(latitude: 26.2124, longitude: 127.6809, regionName: '那覇'),
  LocationValue(latitude: 37.9161, longitude: 139.0364, regionName: '新潟'),
  LocationValue(latitude: 36.5613, longitude: 136.6562, regionName: '金沢'),
  LocationValue(latitude: 34.6851, longitude: 135.8050, regionName: '奈良'),
  LocationValue(latitude: 34.6901, longitude: 135.1955, regionName: '神戸'),
  LocationValue(latitude: 33.8416, longitude: 132.7657, regionName: '松山'),
];
