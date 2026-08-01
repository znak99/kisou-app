import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../utils/api_error.dart';
import 'ad_reward_provider.dart';
import 'forecast_provider.dart';
import 'api_provider.dart';
import 'feedback_provider.dart';
import 'home_provider.dart';
import 'outlook_quota_provider.dart';
import 'shell_provider.dart';
import 'theme_provider.dart';
import 'travel_plan_provider.dart';
import 'user_provider.dart';

enum AuthStatus { unauthenticated, authenticated }

enum LocalCleanupScope {
  logout,
  accountDeletionRequest,
  accountDeletion,
  accountSwitch,
}

class AuthState {
  const AuthState._({
    required this.status,
    required this.isNewUser,
    this.startupErrorKind,
    this.localCleanupScope,
  });

  const AuthState.unauthenticated({
    ApiErrorKind? startupErrorKind,
    LocalCleanupScope? localCleanupScope,
  }) : this._(
         status: AuthStatus.unauthenticated,
         isNewUser: false,
         startupErrorKind: startupErrorKind,
         localCleanupScope: localCleanupScope,
       );

  const AuthState.authenticated({required bool isNewUser})
    : this._(status: AuthStatus.authenticated, isNewUser: isNewUser);

  final AuthStatus status;
  final bool isNewUser;
  final ApiErrorKind? startupErrorKind;
  final LocalCleanupScope? localCleanupScope;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get localCleanupRequired => localCleanupScope != null;
}

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final authService = ref.read(authServiceProvider);
    await authService.clearKeychainOnFirstLaunch();
    var interruptedTransition = await authService.readLocalCleanupTransition();
    if (interruptedTransition ==
        LocalCleanupTransition.accountDeletionRequested) {
      final confirmed = await _resumeAccountDeletionRequest();
      if (!confirmed) {
        return const AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountDeletionRequest,
        );
      }
      interruptedTransition = LocalCleanupTransition.accountDeletion;
    }
    if (interruptedTransition != null) {
      final scope = _scopeFor(interruptedTransition);
      final cleanupFailure = await _runScopedCleanup(scope);
      if (cleanupFailure != null) {
        return AuthState.unauthenticated(localCleanupScope: scope);
      }
    }

    final hasToken = await authService.hasToken();
    if (hasToken) {
      final onboardingCompleted = await authService.isOnboardingCompleted();
      final isNewUser = !onboardingCompleted;
      return AuthState.authenticated(isNewUser: isNewUser);
    }
    // A missing session may follow expiry, an interrupted logout, or external
    // token removal. Never create a new anonymous account while the previous
    // account's device-local data can still be exposed.
    await authService.markLocalCleanupTransition(
      LocalCleanupTransition.accountSwitch,
    );
    final transitionFailure = await _runCleanupOperations(
      _cleanupOperations(LocalCleanupScope.accountSwitch),
    );
    if (transitionFailure != null) {
      return const AuthState.unauthenticated(
        localCleanupScope: LocalCleanupScope.accountSwitch,
      );
    }
    // No token yet: issue an anonymous account so the app is usable without
    // signing in. Falls back to the login screen only if that fails (offline).
    try {
      final isNewUser = await authService.loginAnonymous(
        dio: ref.read(apiClientProvider),
      );
      await authService.setOnboardingCompleted(!isNewUser);
      await authService.clearLocalCleanupTransition();
      return AuthState.authenticated(isNewUser: isNewUser);
    } catch (error) {
      try {
        await authService.logoutServer(dio: ref.read(apiClientProvider));
      } catch (_) {
        // Anonymous session cleanup is also best-effort while offline.
      }
      final cleanupFailure = await _runScopedCleanup(
        LocalCleanupScope.accountSwitch,
      );
      if (cleanupFailure != null) {
        return const AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountSwitch,
        );
      }
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
    final authService = ref.read(authServiceProvider);
    await authService.markLocalCleanupTransition(LocalCleanupTransition.logout);
    state = const AsyncLoading<AuthState>();
    try {
      await authService.logoutServer(dio: ref.read(apiClientProvider));
    } catch (_) {
      // Server logout is best-effort. Local logout must still complete on a
      // shared/offline device so the next user cannot inherit local data.
    }

    final cleanupFailure = await _runScopedCleanup(LocalCleanupScope.logout);
    _invalidateUserScopedData();
    state = AsyncData(
      AuthState.unauthenticated(
        localCleanupScope: cleanupFailure == null
            ? null
            : LocalCleanupScope.logout,
      ),
    );
    if (cleanupFailure != null) {
      Error.throwWithStackTrace(
        LocalAccountCleanupException(cleanupFailure.error),
        cleanupFailure.stackTrace,
      );
    }
  }

  Future<void> expireSession() async {
    final authService = ref.read(authServiceProvider);
    try {
      await authService.markLocalCleanupTransition(
        LocalCleanupTransition.accountSwitch,
      );
    } catch (_) {
      // Continue local sign-out even if the crash-recovery marker cannot be
      // written; completing cleanup in this process is still safer.
    }
    final cleanupFailure = await _runScopedCleanup(
      LocalCleanupScope.accountSwitch,
    );
    _invalidateUserScopedData();
    state = AsyncData(
      AuthState.unauthenticated(
        localCleanupScope: cleanupFailure == null
            ? null
            : LocalCleanupScope.accountSwitch,
      ),
    );
  }

  /// Finalizes a successful server-side account deletion without issuing a
  /// logout request against an account that no longer exists.
  Future<void> completeAccountDeletion() async {
    await ref
        .read(authServiceProvider)
        .markLocalCleanupTransition(LocalCleanupTransition.accountDeletion);
    await _completeAccountDeletion();
  }

  Future<void> _completeAccountDeletion() async {
    state = const AsyncLoading<AuthState>();
    final cleanupFailure = await _runScopedCleanup(
      LocalCleanupScope.accountDeletion,
    );
    _invalidateUserScopedData();
    state = AsyncData(
      AuthState.unauthenticated(
        localCleanupScope: cleanupFailure == null
            ? null
            : LocalCleanupScope.accountDeletion,
      ),
    );
    if (cleanupFailure != null) {
      Error.throwWithStackTrace(
        LocalAccountCleanupException(cleanupFailure.error),
        cleanupFailure.stackTrace,
      );
    }
  }

  /// Deletes the server account first, then removes every local credential.
  /// Both onboarding and profile use this single coordinator so no created
  /// guest account is left without an in-app deletion path.
  Future<void> deleteAccount() async {
    final authService = ref.read(authServiceProvider);
    await authService.markLocalCleanupTransition(
      LocalCleanupTransition.accountDeletionRequested,
    );
    try {
      await ref.read(userProvider.notifier).deleteMe();
    } catch (error, stackTrace) {
      _invalidateUserScopedData();
      state = const AsyncData(
        AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountDeletionRequest,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    try {
      await authService.markLocalCleanupTransition(
        LocalCleanupTransition.accountDeletion,
      );
    } catch (error, stackTrace) {
      _invalidateUserScopedData();
      state = const AsyncData(
        AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountDeletionRequest,
        ),
      );
      Error.throwWithStackTrace(
        LocalAccountCleanupException(error),
        stackTrace,
      );
    }
    await _completeAccountDeletion();
  }

  /// Re-attempts the exact local cleanup scope without creating an account.
  Future<bool> retryLocalAccountCleanup() async {
    final scope = state.value?.localCleanupScope;
    if (scope == null) {
      return true;
    }
    final authService = ref.read(authServiceProvider);
    var cleanupScope = scope;
    if (scope == LocalCleanupScope.accountDeletionRequest) {
      final confirmed = await _resumeAccountDeletionRequest();
      if (!confirmed) {
        state = const AsyncData(
          AuthState.unauthenticated(
            localCleanupScope: LocalCleanupScope.accountDeletionRequest,
          ),
        );
        return false;
      }
      cleanupScope = LocalCleanupScope.accountDeletion;
    }
    try {
      await authService.markLocalCleanupTransition(
        _transitionFor(cleanupScope),
      );
    } catch (_) {
      // If all cleanup operations succeed below, no recovery marker remains
      // necessary. A failed operation keeps the in-memory recovery screen.
    }
    final cleanupFailure = await _runScopedCleanup(cleanupScope);
    _invalidateUserScopedData();
    state = AsyncData(
      AuthState.unauthenticated(
        localCleanupScope: cleanupFailure == null ? null : cleanupScope,
      ),
    );
    return cleanupFailure == null;
  }

  Future<_CleanupFailure?> _runCleanupOperations(
    List<Future<void> Function()> operations,
  ) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final operation in operations) {
      try {
        await operation();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError == null) {
      return null;
    }
    return _CleanupFailure(firstError, firstStackTrace!);
  }

  List<Future<void> Function()> _cleanupOperations(LocalCleanupScope scope) {
    final authService = ref.read(authServiceProvider);
    return switch (scope) {
      LocalCleanupScope.logout || LocalCleanupScope.accountSwitch => [
        () => ref.read(travelPlanProvider.notifier).clearAllLocalData(),
        authService.clearTokens,
        authService.clearOnboardingCompleted,
      ],
      LocalCleanupScope.accountDeletion => [
        () => ref.read(travelPlanProvider.notifier).clearAllLocalData(),
        () async {
          ref.read(themeModeProvider.notifier).resetAfterAccountDeletion();
        },
      ],
      LocalCleanupScope.accountDeletionRequest => const [],
    };
  }

  Future<_CleanupFailure?> _runScopedCleanup(LocalCleanupScope scope) async {
    final authService = ref.read(authServiceProvider);
    final cleanupFailure = await _runCleanupOperations(
      _cleanupOperations(scope),
    );
    if (cleanupFailure != null) {
      // Do not remove auth credentials/preferences after another scoped store
      // failed. The secure transition marker and retry context must remain
      // intact until every account-bound cleanup can complete.
      return cleanupFailure;
    }
    if (scope == LocalCleanupScope.accountDeletion) {
      try {
        // Clear auth-owned credentials and preferences only after the other
        // stores succeed. AuthService deliberately preserves the secure
        // transition marker until the explicit clear below.
        await authService.clearLocalAccountData();
      } catch (error, stackTrace) {
        return _CleanupFailure(error, stackTrace);
      }
    }
    try {
      await authService.clearLocalCleanupTransition();
      return null;
    } catch (error, stackTrace) {
      return _CleanupFailure(error, stackTrace);
    }
  }

  Future<bool> _resumeAccountDeletionRequest() async {
    try {
      await ref.read(userProvider.notifier).deleteMe();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != 401) {
        return false;
      }
      // Fallback for a response lost after DELETE committed: this API has no
      // deletion receipt and no longer resolves a deleted user's JWT. A 401 is
      // also possible for an unrelated expired/invalid token, so this is not
      // definitive proof; a server idempotency/status API remains necessary.
    } catch (_) {
      // The request may not have reached the server, so do not claim local
      // completion or erase the marker. The recovery screen offers a retry.
      return false;
    }
    try {
      await ref
          .read(authServiceProvider)
          .markLocalCleanupTransition(LocalCleanupTransition.accountDeletion);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Drops all cached per-user data so a subsequent account never sees the
  /// previous user's home/forecast/feedback/profile — audit B6.
  void _invalidateUserScopedData() {
    ref.invalidate(homeProvider);
    ref.invalidate(forecastTomorrowProvider);
    ref.invalidate(forecastOutlookProvider);
    ref.invalidate(outlookQuotaProvider);
    ref.invalidate(adRewardProvider);
    ref.invalidate(feedbackProvider);
    ref.invalidate(userProvider);
    ref.invalidate(travelPlanProvider);
    ref.invalidate(travelNotificationNavigationProvider);
    ref.invalidate(shellTabProvider);
  }

  Future<void> completeOnboarding() async {
    await ref.read(authServiceProvider).setOnboardingCompleted(true);
    state = const AsyncData(AuthState.authenticated(isNewUser: false));
  }

  Future<void> _login(
    Future<bool> Function(AuthService authService, Dio dio) login,
  ) async {
    if (state.value?.localCleanupRequired == true) {
      throw StateError('Local account cleanup must finish before login.');
    }
    final authService = ref.read(authServiceProvider);
    await authService.markLocalCleanupTransition(
      LocalCleanupTransition.accountSwitch,
    );
    state = const AsyncLoading<AuthState>();

    // Clear the previous account before the server can persist a new token.
    // The marker remains until the new session is fully finalized, covering
    // process death and partial secure-storage writes.
    final priorCleanupFailure = await _runCleanupOperations(
      _cleanupOperations(LocalCleanupScope.accountSwitch),
    );
    if (priorCleanupFailure != null) {
      _invalidateUserScopedData();
      state = const AsyncData(
        AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountSwitch,
        ),
      );
      return;
    }

    final loginResult = await AsyncValue.guard(
      () => login(authService, ref.read(apiClientProvider)),
    );
    if (loginResult.hasError) {
      try {
        await authService.logoutServer(dio: ref.read(apiClientProvider));
      } catch (_) {
        // Best-effort revocation covers partial server/session writes.
      }
      final cleanupFailure = await _runScopedCleanup(
        LocalCleanupScope.accountSwitch,
      );
      _invalidateUserScopedData();
      state = cleanupFailure == null
          ? AsyncError(loginResult.error!, loginResult.stackTrace!)
          : const AsyncData(
              AuthState.unauthenticated(
                localCleanupScope: LocalCleanupScope.accountSwitch,
              ),
            );
      return;
    }

    final isNewUser = loginResult.requireValue;
    try {
      await authService.setOnboardingCompleted(!isNewUser);
      await authService.clearLocalCleanupTransition();
    } catch (error, stackTrace) {
      // The server session exists, but local finalization failed. Revoke it
      // best-effort and remove local tokens before leaving the loading state.
      try {
        await authService.logoutServer(dio: ref.read(apiClientProvider));
      } catch (_) {
        // [logoutServer] is best-effort by contract, including offline use.
      }
      final cleanupFailure = await _runScopedCleanup(
        LocalCleanupScope.accountSwitch,
      );
      _invalidateUserScopedData();
      state = cleanupFailure == null
          ? AsyncError(error, stackTrace)
          : const AsyncData(
              AuthState.unauthenticated(
                localCleanupScope: LocalCleanupScope.accountSwitch,
              ),
            );
      return;
    }
    _invalidateUserScopedData();
    ref.read(authRequiredProvider.notifier).clear();
    state = AsyncData(AuthState.authenticated(isNewUser: isNewUser));
  }
}

LocalCleanupScope _scopeFor(LocalCleanupTransition transition) {
  return switch (transition) {
    LocalCleanupTransition.logout => LocalCleanupScope.logout,
    LocalCleanupTransition.accountDeletionRequested =>
      LocalCleanupScope.accountDeletionRequest,
    LocalCleanupTransition.accountDeletion => LocalCleanupScope.accountDeletion,
    LocalCleanupTransition.accountSwitch => LocalCleanupScope.accountSwitch,
  };
}

LocalCleanupTransition _transitionFor(LocalCleanupScope scope) {
  return switch (scope) {
    LocalCleanupScope.logout => LocalCleanupTransition.logout,
    LocalCleanupScope.accountDeletionRequest =>
      LocalCleanupTransition.accountDeletionRequested,
    LocalCleanupScope.accountDeletion => LocalCleanupTransition.accountDeletion,
    LocalCleanupScope.accountSwitch => LocalCleanupTransition.accountSwitch,
  };
}

class LocalAccountCleanupException implements Exception {
  const LocalAccountCleanupException(this.cause);

  final Object cause;
}

class _CleanupFailure {
  const _CleanupFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
