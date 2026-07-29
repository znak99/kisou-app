import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../utils/api_error.dart';
import 'forecast_provider.dart';
import 'api_provider.dart';
import 'feedback_provider.dart';
import 'home_provider.dart';
import 'shell_provider.dart';
import 'user_provider.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  const AuthState._({
    required this.status,
    required this.isNewUser,
    this.startupErrorKind,
  });

  const AuthState.unauthenticated({ApiErrorKind? startupErrorKind})
    : this._(
        status: AuthStatus.unauthenticated,
        isNewUser: false,
        startupErrorKind: startupErrorKind,
      );

  const AuthState.authenticated({required bool isNewUser})
    : this._(status: AuthStatus.authenticated, isNewUser: isNewUser);

  final AuthStatus status;
  final bool isNewUser;
  final ApiErrorKind? startupErrorKind;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final authService = ref.read(authServiceProvider);
    await authService.clearKeychainOnFirstLaunch();
    final hasToken = await authService.hasToken();
    if (hasToken) {
      final onboardingCompleted = await authService.isOnboardingCompleted();
      final isNewUser = !onboardingCompleted;
      return AuthState.authenticated(isNewUser: isNewUser);
    }
    // No token yet: issue an anonymous account so the app is usable without
    // signing in. Falls back to the login screen only if that fails (offline).
    try {
      final isNewUser = await authService.loginAnonymous(
        dio: ref.read(apiClientProvider),
      );
      await authService.setOnboardingCompleted(!isNewUser);
      return AuthState.authenticated(isNewUser: isNewUser);
    } catch (error) {
      return AuthState.unauthenticated(
        startupErrorKind: classifyApiError(error),
      );
    }
  }

  /// Links the current anonymous account to Apple, then refreshes state.
  Future<void> linkWithApple() async {
    await ref
        .read(authServiceProvider)
        .linkWithApple(dio: ref.read(apiClientProvider));
  }

  /// Links the current anonymous account to Google, then refreshes state.
  Future<void> linkWithGoogle() async {
    await ref
        .read(authServiceProvider)
        .linkWithGoogle(dio: ref.read(apiClientProvider));
  }

  /// Development-only account linking (uses a fake provider token).
  Future<void> linkWithDevelopment() async {
    await ref
        .read(authServiceProvider)
        .linkWithDevelopment(dio: ref.read(apiClientProvider));
  }

  Future<void> loginWithApple() {
    return _login((authService, dio) {
      return authService.loginWithApple(dio: dio);
    });
  }

  Future<void> loginWithGoogle() {
    return _login((authService, dio) {
      return authService.loginWithGoogle(dio: dio);
    });
  }

  Future<void> loginWithDevelopmentExistingUser() {
    return _login((authService, dio) {
      return authService.loginWithDevelopmentExistingUser(dio: dio);
    });
  }

  Future<void> loginWithDevelopmentNewUser() {
    return _login((authService, dio) {
      return authService.loginWithDevelopmentNewUser(dio: dio);
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading<AuthState>();
    final authService = ref.read(authServiceProvider);
    await authService.logoutServer(dio: ref.read(apiClientProvider));
    await authService.clearTokens();
    await authService.clearOnboardingCompleted();
    _invalidateUserScopedData();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> expireSession() async {
    final authService = ref.read(authServiceProvider);
    await authService.clearTokens();
    await authService.clearOnboardingCompleted();
    _invalidateUserScopedData();
    state = const AsyncData(AuthState.unauthenticated());
  }

  /// Drops all cached per-user data so a subsequent account never sees the
  /// previous user's home/forecast/feedback/profile — audit B6.
  void _invalidateUserScopedData() {
    ref.invalidate(homeProvider);
    ref.invalidate(forecastTomorrowProvider);
    ref.invalidate(forecastOutlookProvider);
    ref.invalidate(feedbackProvider);
    ref.invalidate(userProvider);
    ref.invalidate(shellTabProvider);
  }

  Future<void> completeOnboarding() async {
    await ref.read(authServiceProvider).setOnboardingCompleted(true);
    state = const AsyncData(AuthState.authenticated(isNewUser: false));
  }

  Future<void> _login(
    Future<bool> Function(AuthService authService, Dio dio) login,
  ) async {
    state = const AsyncLoading<AuthState>();
    state = await AsyncValue.guard(() async {
      final isNewUser = await login(
        ref.read(authServiceProvider),
        ref.read(apiClientProvider),
      );
      await ref.read(authServiceProvider).setOnboardingCompleted(!isNewUser);
      // Switching accounts: drop the prior account's cached data.
      _invalidateUserScopedData();
      ref.read(authRequiredProvider.notifier).clear();
      return AuthState.authenticated(isNewUser: isNewUser);
    });
  }
}
