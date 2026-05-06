class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.isNewUser,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: (json['access_token'] ?? json['accessToken']) as String,
      tokenType:
          (json['token_type'] ?? json['tokenType']) as String? ?? 'bearer',
      isNewUser: (json['is_new_user'] ?? json['isNewUser']) as bool? ?? false,
    );
  }

  final String accessToken;
  final String tokenType;
  final bool isNewUser;
}
