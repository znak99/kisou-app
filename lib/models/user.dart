class User {
  const User({
    required this.id,
    required this.authProvider,
    required this.nickname,
    required this.gender,
    required this.coldSensitivity,
    required this.heatSensitivity,
    required this.offsetValue,
    required this.departureTime,
    required this.returnTime,
    required this.latitude,
    required this.longitude,
    required this.regionName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      authProvider: json['auth_provider'] as String? ?? 'anonymous',
      nickname: json['nickname'] as String,
      gender: json['gender'] as String,
      coldSensitivity: json['cold_sensitivity'] as String,
      heatSensitivity: json['heat_sensitivity'] as String,
      offsetValue: (json['offset_value'] as num).toDouble(),
      departureTime: json['departure_time'] as String,
      returnTime: json['return_time'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      regionName: json['region_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String authProvider;
  final String nickname;

  bool get isAnonymous => authProvider == 'anonymous';
  final String gender;
  final String coldSensitivity;
  final String heatSensitivity;
  final double offsetValue;
  final String departureTime;
  final String returnTime;
  final double? latitude;
  final double? longitude;
  final String? regionName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_provider': authProvider,
      'nickname': nickname,
      'gender': gender,
      'cold_sensitivity': coldSensitivity,
      'heat_sensitivity': heatSensitivity,
      'offset_value': offsetValue,
      'departure_time': departureTime,
      'return_time': returnTime,
      'latitude': latitude,
      'longitude': longitude,
      'region_name': regionName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class UserUpdate {
  const UserUpdate({
    this.nickname,
    this.gender,
    this.coldSensitivity,
    this.heatSensitivity,
    this.departureTime,
    this.returnTime,
    this.latitude,
    this.longitude,
    this.regionName,
  });

  final String? nickname;
  final String? gender;
  final String? coldSensitivity;
  final String? heatSensitivity;
  final String? departureTime;
  final String? returnTime;
  final double? latitude;
  final double? longitude;
  final String? regionName;

  Map<String, dynamic> toJson() {
    return {
      if (nickname != null) 'nickname': nickname,
      if (gender != null) 'gender': gender,
      if (coldSensitivity != null) 'cold_sensitivity': coldSensitivity,
      if (heatSensitivity != null) 'heat_sensitivity': heatSensitivity,
      if (departureTime != null) 'departure_time': departureTime,
      if (returnTime != null) 'return_time': returnTime,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (regionName != null) 'region_name': regionName,
    };
  }
}
