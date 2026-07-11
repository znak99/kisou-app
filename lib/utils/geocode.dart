import 'package:geocoding/geocoding.dart';

/// Reverse-geocodes coordinates into a Japanese region label such as
/// "東京都 新宿区". Returns null on failure so callers can fall back.
Future<String?> reverseGeocodeRegion(double latitude, double longitude) async {
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
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' ');
  } catch (_) {
    return null;
  }
}
