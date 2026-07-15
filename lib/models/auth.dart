class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.isNewUser,
    this.deviceSecret,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: (json['access_token'] ?? json['accessToken']) as String,
      refreshToken: (json['refresh_token'] ?? json['refreshToken']) as String,
      tokenType:
          (json['token_type'] ?? json['tokenType']) as String? ?? 'bearer',
      isNewUser: (json['is_new_user'] ?? json['isNewUser']) as bool? ?? false,
      deviceSecret: (json['device_secret'] ?? json['deviceSecret']) as String?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool isNewUser;

  /// Only present when the server just created a new anonymous account; store
  /// it securely and send it back as `device_secret` on future anonymous logins.
  final String? deviceSecret;
}
