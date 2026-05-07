import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authRequiredProvider = NotifierProvider<AuthRequiredNotifier, bool>(
  AuthRequiredNotifier.new,
);

class AuthRequiredNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void requireAuth() {
    state = true;
  }

  void clear() {
    state = false;
  }
}

final apiClientProvider = Provider<Dio>((ref) {
  final authService = ref.watch(authServiceProvider);

  return ApiClient(
    authService: authService,
    onUnauthorized: () {
      ref.read(authRequiredProvider.notifier).requireAuth();
    },
  ).dio;
});
