import 'package:geocoding/geocoding.dart';

class GeocodedRegion {
  const GeocodedRegion({required this.regionName, required this.countryCode});

  final String? regionName;
  final String? countryCode;

  bool get isJapan => countryCode?.toUpperCase() == 'JP';
}

bool isUsableJapanLocation(GeocodedRegion? location) {
  return location != null &&
      location.isJapan &&
      (location.regionName?.trim().isNotEmpty ?? false);
}

/// Reverse-geocodes coordinates and retains the ISO country code so callers
/// can reject locations outside KISOU's Japan-only service area.
Future<GeocodedRegion?> reverseGeocodeLocation(
  double latitude,
  double longitude,
) async {
  try {
    await setLocaleIdentifier('ja_JP');
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) {
      return null;
    }
    final place = placemarks.first;
    final admin = place.administrativeArea?.trim() ?? ''; // 都道府県
    var locality = place.locality?.trim() ?? ''; // 市区町村
    if (locality.isEmpty) {
      locality = place.subAdministrativeArea?.trim() ?? '';
    }

    final parts = <String>[];
    if (admin.isNotEmpty) {
      parts.add(admin);
    }
    if (locality.isNotEmpty && locality != admin) {
      parts.add(locality);
    }
    return GeocodedRegion(
      regionName: parts.isEmpty ? null : parts.join(' '),
      countryCode: place.isoCountryCode?.trim(),
    );
  } catch (_) {
    return null;
  }
}

/// Reverse-geocodes coordinates into a Japanese region label such as
/// "東京都 新宿区". Returns null on failure so callers can fall back.
Future<String?> reverseGeocodeRegion(double latitude, double longitude) async {
  final location = await reverseGeocodeLocation(latitude, longitude);
  return location?.regionName;
}
