class LocationValue {
  const LocationValue({
    required this.latitude,
    required this.longitude,
    required this.regionName,
    this.code,
  });

  final double latitude;
  final double longitude;
  final String regionName;

  /// Stable local identifier for predefined cities.
  ///
  /// GPS-derived locations intentionally have no code and cannot be persisted
  /// as a travel destination without an explicit major-city selection.
  final String? code;
}
