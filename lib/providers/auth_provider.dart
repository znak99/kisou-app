import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/auth_service.dart';
import '../services/push_installation_store.dart';
import '../services/push_messaging_gateway.dart';
import '../utils/api_error.dart';
import 'account_deletion_credential_provider.dart';
import 'ad_reward_provider.dart';
import 'forecast_provider.dart';
import 'api_provider.dart';
import 'feedback_provider.dart';
import 'home_provider.dart';
import 'outlook_quota_provider.dart';
import 'push_provider.dart';
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
  unconfirmedAccountDiscard,
}

enum AccountDeletionRecoveryKind { retryable, authenticationRequired }

class AuthState {
  const AuthState._({
    required this.status,
    required this.isNewUser,
    this.startupErrorKind,
    this.localCleanupScope,
    this.accountDeletionRecoveryKind,
    this.canDiscardUnconfirmedAccountData = false,
  });

  const AuthState.unauthenticated({
    ApiErrorKind? startupErrorKind,
    LocalCleanupScope? localCleanupScope,
    AccountDeletionRecoveryKind? accountDeletionRecoveryKind,
    bool canDiscardUnconfirmedAccountData = false,
  }) : this._(
         status: AuthStatus.unauthenticated,
         isNewUser: false,
         startupErrorKind: startupErrorKind,
         localCleanupScope: localCleanupScope,
         accountDeletionRecoveryKind: accountDeletionRecoveryKind,
         canDiscardUnconfirmedAccountData: canDiscardUnconfirmedAccountData,
       );

  const AuthState.authenticated({required bool isNewUser})
    : this._(status: AuthStatus.authenticated, isNewUser: isNewUser);

  final AuthStatus status;
  final bool isNewUser;
  final ApiErrorKind? startupErrorKind;
  final LocalCleanupScope? localCleanupScope;
  final AccountDeletionRecoveryKind? accountDeletionRecoveryKind;
  final bool canDiscardUnconfirmedAccountData;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get localCleanupRequired => localCleanupScope != null;
}

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final accountDeletionIdempotencyKeyFactoryProvider =
    Provider<String Function()>((ref) {
      const uuid = Uuid();
      return uuid.v4;
    });

class AuthController extends AsyncNotifier<AuthState> {
  Future<void>? _deleteAccountFuture;
  Future<bool>? _discardUnconfirmedAccountDataFuture;
  var _deletionAuthenticationRequired = false;
  var _deletionReceiptNotFound = false;

  @override
  Future<AuthState> build() async {
    final authService = ref.read(authServiceProvider);
    await authService.clearKeychainOnFirstLaunch();
    var interruptedTransition = await authService.readLocalCleanupTransition();
    var pushAlreadyClosed = false;
    if (interruptedTransition ==
        LocalCleanupTransition.accountDeletionRequested) {
      final confirmed = await _resumeAccountDeletionRequest();
      if (!confirmed) {
        return AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountDeletionRequest,
          accountDeletionRecoveryKind: _deletionRecoveryKind,
          canDiscardUnconfirmedAccountData: _canDiscardUnconfirmedAccountData,
        );
      }
      pushAlreadyClosed = true;
      interruptedTransition = LocalCleanupTransition.accountDeletion;
    }
    if (interruptedTransition != null) {
      final scope = _scopeFor(interruptedTransition);
      final cleanupFailure = await _runScopedCleanup(
        scope,
        pushAlreadyClosed: pushAlreadyClosed,
      );
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
    final transitionFailure = await _runScopedCleanup(
      LocalCleanupScope.accountSwitch,
      clearTransitionOnSuccess: false,
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
    // Unregister while the old refresh/access session is still usable.
    await _closePushAccountForTransition();
    state = const AsyncLoading<AuthState>();
    try {
      await authService.logoutServer(dio: ref.read(apiClientProvider));
    } catch (_) {
      // Server logout is best-effort. Local logout must still complete on a
      // shared/offline device so the next user cannot inherit local data.
    }

    final cleanupFailure = await _runScopedCleanup(
      LocalCleanupScope.logout,
      pushAlreadyClosed: true,
    );
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
    final persistedTransition = await authService.readLocalCleanupTransition();
    if (_deleteAccountFuture != null ||
        _discardUnconfirmedAccountDataFuture != null) {
      // The active coordinator owns both the durable marker and final state.
      // Writing here could resurrect a recovery screen after cleanup finishes
      // but before the coordinator Future runs its whenComplete callback.
      return;
    }
    if (persistedTransition ==
            LocalCleanupTransition.accountDeletionRequested ||
        persistedTransition == LocalCleanupTransition.accountDeletion ||
        persistedTransition ==
            LocalCleanupTransition.unconfirmedAccountDiscard) {
      final scope = switch (persistedTransition) {
        LocalCleanupTransition.accountDeletion =>
          LocalCleanupScope.accountDeletion,
        LocalCleanupTransition.unconfirmedAccountDiscard =>
          LocalCleanupScope.unconfirmedAccountDiscard,
        _ => LocalCleanupScope.accountDeletionRequest,
      };
      // A concurrent 401 must never downgrade a deletion receipt capability
      // into accountSwitch or erase the data needed for status recovery.
      state = AsyncData(AuthState.unauthenticated(localCleanupScope: scope));
      return;
    }
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

  Future<void> _completeAccountDeletion({
    bool pushAlreadyClosed = false,
  }) async {
    state = const AsyncLoading<AuthState>();
    final cleanupFailure = await _runScopedCleanup(
      LocalCleanupScope.accountDeletion,
      pushAlreadyClosed: pushAlreadyClosed,
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
  Future<void> deleteAccount() {
    return _deleteAccountFuture ??= _deleteAccount().whenComplete(() {
      _deleteAccountFuture = null;
    });
  }

  Future<void> _deleteAccount() async {
    final authService = ref.read(authServiceProvider);
    final idempotencyKey = ref.read(
      accountDeletionIdempotencyKeyFactoryProvider,
    )();
    await authService.markAccountDeletionRequested(idempotencyKey);
    await _closePushAccountForTransition();
    final confirmed = await _requestDeletionAndConfirm(idempotencyKey);
    if (!confirmed) {
      _invalidateUserScopedData();
      state = AsyncData(
        AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountDeletionRequest,
          accountDeletionRecoveryKind: _deletionRecoveryKind,
          canDiscardUnconfirmedAccountData: _canDiscardUnconfirmedAccountData,
        ),
      );
      throw const AccountDeletionConfirmationException();
    }
    try {
      await authService.markAccountDeletionConfirmed(idempotencyKey);
    } catch (error, stackTrace) {
      _invalidateUserScopedData();
      state = AsyncData(
        AuthState.unauthenticated(
          localCleanupScope: LocalCleanupScope.accountDeletionRequest,
          accountDeletionRecoveryKind: _deletionRecoveryKind,
          canDiscardUnconfirmedAccountData: _canDiscardUnconfirmedAccountData,
        ),
      );
      Error.throwWithStackTrace(
        LocalAccountCleanupException(error),
        stackTrace,
      );
    }
    await _completeAccountDeletion(pushAlreadyClosed: true);
  }

  /// Re-attempts the exact local cleanup scope without creating an account.
  Future<bool> retryLocalAccountCleanup() async {
    final scope = state.value?.localCleanupScope;
    if (scope == null) {
      return true;
    }
    final authService = ref.read(authServiceProvider);
    var cleanupScope = scope;
    var pushAlreadyClosed = false;
    if (scope == LocalCleanupScope.accountDeletionRequest) {
      final confirmed = await _resumeAccountDeletionRequest();
      if (!confirmed) {
        state = AsyncData(
          AuthState.unauthenticated(
            localCleanupScope: LocalCleanupScope.accountDeletionRequest,
            accountDeletionRecoveryKind: _deletionRecoveryKind,
            canDiscardUnconfirmedAccountData: _canDiscardUnconfirmedAccountData,
          ),
        );
        return false;
      }
      pushAlreadyClosed = true;
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
    final cleanupFailure = await _runScopedCleanup(
      cleanupScope,
      pushAlreadyClosed: pushAlreadyClosed,
    );
    _invalidateUserScopedData();
    state = AsyncData(
      AuthState.unauthenticated(
        localCleanupScope: cleanupFailure == null ? null : cleanupScope,
      ),
    );
    return cleanupFailure == null;
  }

  /// Explicitly abandons only this device's unconfirmed deletion recovery.
  ///
  /// This never claims that the server account was deleted and never sends
  /// another DELETE. It is available only after a definitive receipt 404 and
  /// failure to restore the exact original session. The dedicated discard
  /// marker makes full identity cleanup resume safely after a process restart.
  Future<bool> discardUnconfirmedAccountData() {
    return _discardUnconfirmedAccountDataFuture ??=
        _discardUnconfirmedAccountData().whenComplete(() {
          _discardUnconfirmedAccountDataFuture = null;
        });
  }

  Future<bool> _discardUnconfirmedAccountData() async {
    final current = state.value;
    if (current?.localCleanupScope !=
            LocalCleanupScope.accountDeletionRequest ||
        current?.accountDeletionRecoveryKind !=
            AccountDeletionRecoveryKind.authenticationRequired ||
        current?.canDiscardUnconfirmedAccountData != true) {
      throw StateError('Unconfirmed local account discard is not allowed.');
    }
    final authService = ref.read(authServiceProvider);
    try {
      final transition = await authService.readLocalCleanupTransition();
      if (transition != LocalCleanupTransition.accountDeletionRequested) {
        return false;
      }
      await authService.markLocalCleanupTransition(
        LocalCleanupTransition.unconfirmedAccountDiscard,
      );
    } catch (_) {
      // The deletion UUID marker remains authoritative when the crash-safe
      // local-discard marker cannot be persisted.
      return false;
    }

    final cleanupFailure = await _runScopedCleanup(
      LocalCleanupScope.unconfirmedAccountDiscard,
    );
    _invalidateUserScopedData();
    state = AsyncData(
      AuthState.unauthenticated(
        localCleanupScope: cleanupFailure == null
            ? null
            : LocalCleanupScope.unconfirmedAccountDiscard,
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

  List<Future<void> Function()> _preCredentialCleanupOperations(
    LocalCleanupScope scope, {
    bool includePush = true,
  }) {
    return switch (scope) {
      LocalCleanupScope.logout || LocalCleanupScope.accountSwitch => [
        if (includePush) _closePushAccountForTransition,
        () async {
          ref.invalidate(adRewardProvider);
        },
        () => ref.read(travelPlanProvider.notifier).clearAllLocalData(),
        // Linking preserves this code because the user ID stays the same. A
        // full account transition removes it before another account can use
        // the device.
        () => ref.read(accountDeletionCredentialStoreProvider).delete(),
      ],
      LocalCleanupScope.accountDeletion ||
      LocalCleanupScope.unconfirmedAccountDiscard => [
        if (includePush) _closePushAccountForTransition,
        () async {
          ref.invalidate(adRewardProvider);
        },
        () => ref.read(travelPlanProvider.notifier).clearAllLocalData(),
        () => ref.read(accountDeletionCredentialStoreProvider).delete(),
        () async {
          ref.read(themeModeProvider.notifier).resetAfterAccountDeletion();
        },
      ],
      LocalCleanupScope.accountDeletionRequest => const [],
    };
  }

  Future<_CleanupFailure?> _runAuthOwnedCleanup(LocalCleanupScope scope) async {
    final authService = ref.read(authServiceProvider);
    try {
      switch (scope) {
        case LocalCleanupScope.logout:
        case LocalCleanupScope.accountSwitch:
          // The old session remains available for push unregister until every
          // independent account-bound store has finished. Within this final
          // phase, remove the access/refresh tokens last so an earlier local
          // preference failure also remains retryable.
          await authService.clearPendingAdRewardOperation();
          await authService.clearOnboardingCompleted();
          await authService.clearTokens();
        case LocalCleanupScope.accountDeletion:
        case LocalCleanupScope.unconfirmedAccountDiscard:
          // The server account is already deleted, or the user explicitly
          // chose irreversible local-only abandonment.
          await authService.clearLocalAccountData();
        case LocalCleanupScope.accountDeletionRequest:
          break;
      }
      return null;
    } catch (error, stackTrace) {
      return _CleanupFailure(error, stackTrace);
    }
  }

  Future<_CleanupFailure?> _runScopedCleanup(
    LocalCleanupScope scope, {
    bool pushAlreadyClosed = false,
    bool clearTransitionOnSuccess = true,
  }) async {
    final authService = ref.read(authServiceProvider);
    final cleanupFailure = await _runCleanupOperations(
      _preCredentialCleanupOperations(scope, includePush: !pushAlreadyClosed),
    );
    if (cleanupFailure != null) {
      // The access/refresh session is the capability needed to retry server
      // unregister. Keep all auth-owned data and the transition marker intact
      // until push and every other independent account store are clean.
      return cleanupFailure;
    }
    final authCleanupFailure = await _runAuthOwnedCleanup(scope);
    if (authCleanupFailure != null) {
      return authCleanupFailure;
    }
    if (!clearTransitionOnSuccess) {
      // Login and startup account replacement retain the crash marker until
      // the replacement session and onboarding state are durably finalized.
      return null;
    }
    try {
      await authService.clearLocalCleanupTransition();
      return null;
    } catch (error, stackTrace) {
      return _CleanupFailure(error, stackTrace);
    }
  }

  Future<bool> _resumeAccountDeletionRequest() async {
    _deletionAuthenticationRequired = false;
    _deletionReceiptNotFound = false;
    final authService = ref.read(authServiceProvider);
    try {
      await _closePushAccountForTransition();
    } catch (_) {
      // A durable installation revision is required before deletion can
      // proceed; preserve the deletion marker and retry later.
      return false;
    }
    var idempotencyKey = await authService
        .readAccountDeletionRequestIdempotencyKey();
    if (idempotencyKey != null &&
        await _lookupDeletionReceipt(idempotencyKey) ==
            _DeletionReceiptLookup.completed) {
      return _markAccountDeletionConfirmed(idempotencyKey);
    }
    if (idempotencyKey == null) {
      idempotencyKey = ref.read(accountDeletionIdempotencyKeyFactoryProvider)();
      try {
        await authService.markAccountDeletionRequested(idempotencyKey);
      } catch (_) {
        return false;
      }
    }
    if (!await _requestDeletionAndConfirm(idempotencyKey)) {
      return false;
    }
    return _markAccountDeletionConfirmed(idempotencyKey);
  }

  Future<bool> _requestDeletionAndConfirm(String idempotencyKey) async {
    _deletionAuthenticationRequired = false;
    _deletionReceiptNotFound = false;
    if (await _lookupDeletionReceipt(idempotencyKey) ==
        _DeletionReceiptLookup.completed) {
      return true;
    }
    var restoredOnce = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      final authService = ref.read(authServiceProvider);
      if (!await authService.hasToken()) {
        if (restoredOnce) {
          _deletionAuthenticationRequired = true;
          return false;
        }
        try {
          final restored = await authService.restoreAnonymousSessionForDeletion(
            dio: ref.read(apiClientProvider),
          );
          if (!restored) {
            _deletionAuthenticationRequired = true;
            return false;
          }
          restoredOnce = true;
        } catch (_) {
          // Offline/timeout remains retryable. Keep every local credential and
          // the atomic request marker intact.
          return false;
        }
      }
      try {
        await ref
            .read(userProvider.notifier)
            .deleteMe(idempotencyKey: idempotencyKey);
      } catch (_) {
        // A response-lost success and an unrelated 401 are indistinguishable
        // here. Only the unauthenticated receipt endpoint can confirm deletion.
      }
      if (await _lookupDeletionReceipt(idempotencyKey) ==
          _DeletionReceiptLookup.completed) {
        return true;
      }
      if (await authService.hasToken()) {
        return false;
      }
    }
    _deletionAuthenticationRequired = true;
    return false;
  }

  AccountDeletionRecoveryKind get _deletionRecoveryKind =>
      _deletionAuthenticationRequired
      ? AccountDeletionRecoveryKind.authenticationRequired
      : AccountDeletionRecoveryKind.retryable;

  bool get _canDiscardUnconfirmedAccountData =>
      _deletionAuthenticationRequired && _deletionReceiptNotFound;

  Future<_DeletionReceiptLookup> _lookupDeletionReceipt(
    String idempotencyKey,
  ) async {
    try {
      final receipt = await ref
          .read(userServiceProvider)
          .getDeletionStatus(idempotencyKey: idempotencyKey);
      final result = receipt == null
          ? _DeletionReceiptLookup.notFound
          : _DeletionReceiptLookup.completed;
      _deletionReceiptNotFound = result == _DeletionReceiptLookup.notFound;
      return result;
    } catch (_) {
      _deletionReceiptNotFound = false;
      return _DeletionReceiptLookup.unavailable;
    }
  }

  Future<bool> _markAccountDeletionConfirmed(String idempotencyKey) async {
    try {
      await ref
          .read(authServiceProvider)
          .markAccountDeletionConfirmed(idempotencyKey);
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
    ref.invalidate(accountDeletionCredentialProvider);
    ref.invalidate(travelPlanProvider);
    ref.invalidate(travelNotificationNavigationProvider);
    ref.invalidate(pushSettingsProvider);
    ref.invalidate(pushNavigationQueueProvider);
    ref.invalidate(pushForegroundNotificationProvider);
    ref.invalidate(shellTabProvider);
  }

  Future<void> _closePushAccountForTransition() async {
    ref.invalidate(pushSettingsProvider);
    ref.read(pushNavigationQueueProvider.notifier).clear();
    final foreground = ref.read(pushForegroundNotificationProvider);
    if (foreground != null) {
      ref
          .read(pushForegroundNotificationProvider.notifier)
          .clear(foreground.deliveryId);
    }
    if (!ref.read(pushRuntimeEnabledProvider) &&
        !ref.read(pushCleanupRuntimeAvailableProvider)) {
      final inspectionComplete = ref.read(
        pushInstallationStateInspectionCompleteProvider,
      );
      // Unit tests and unsupported desktop targets have no mobile Firebase
      // identity. On Android/iOS, an unreadable secure store is not equivalent
      // to an empty one and must block the account transition for retry.
      if (!inspectionComplete && ref.read(pushPlatformProvider) != null) {
        throw const PushInstallationReadException();
      }
      await ref
          .read(pushDeliveryReceiptStoreProvider)
          .discardUnfinishedAtAccountBoundary();
      return;
    }
    final messaging = ref.read(pushMessagingGatewayProvider);
    await _drainAndClearDisplayedPush(messaging);
    try {
      final closed = await ref
          .read(pushAccountManagerProvider)
          .closeAccount(suppressAuthRecovery: true);
      if (closed.record?.platformCleanupRequired == true) {
        throw PushAccountCloseIncompleteException(closed);
      }
      await ref
          .read(pushDeliveryReceiptStoreProvider)
          .discardUnfinishedAtAccountBoundary();
    } finally {
      // A notification can arrive while unregister/FID deletion is in flight.
      // The client-revision check is authoritative; this second native pass
      // removes already delivered push UI without touching travel reminders.
      await _drainAndClearDisplayedPush(messaging);
    }
  }

  Future<void> _drainAndClearDisplayedPush(
    PushMessagingGateway messaging,
  ) async {
    try {
      // Consume a terminated-launch message before it can reach another
      // account's RootShell.
      await messaging.getInitialMessage();
    } catch (_) {
      // Receipt discard and server revision still protect known deliveries.
    }
    try {
      await messaging.clearDisplayedNotifications();
    } catch (_) {
      // Delivered content is generic and contains no account data. Native
      // clearing is best effort; durable receipts still block known replays.
    }
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
    final priorCleanupFailure = await _runScopedCleanup(
      LocalCleanupScope.accountSwitch,
      clearTransitionOnSuccess: false,
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
    LocalCleanupTransition.unconfirmedAccountDiscard =>
      LocalCleanupScope.unconfirmedAccountDiscard,
  };
}

LocalCleanupTransition _transitionFor(LocalCleanupScope scope) {
  return switch (scope) {
    LocalCleanupScope.logout => LocalCleanupTransition.logout,
    LocalCleanupScope.accountDeletionRequest =>
      LocalCleanupTransition.accountDeletionRequested,
    LocalCleanupScope.accountDeletion => LocalCleanupTransition.accountDeletion,
    LocalCleanupScope.accountSwitch => LocalCleanupTransition.accountSwitch,
    LocalCleanupScope.unconfirmedAccountDiscard =>
      LocalCleanupTransition.unconfirmedAccountDiscard,
  };
}

class LocalAccountCleanupException implements Exception {
  const LocalAccountCleanupException(this.cause);

  final Object cause;
}

class AccountDeletionConfirmationException implements Exception {
  const AccountDeletionConfirmationException();
}

enum _DeletionReceiptLookup { completed, notFound, unavailable }

class _CleanupFailure {
  const _CleanupFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
