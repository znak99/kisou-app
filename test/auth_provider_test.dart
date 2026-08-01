import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/providers/ad_reward_provider.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/providers/auth_provider.dart';
import 'package:kisou_app/providers/shell_provider.dart';
import 'package:kisou_app/providers/outlook_quota_provider.dart';
import 'package:kisou_app/providers/theme_provider.dart';
import 'package:kisou_app/providers/travel_plan_provider.dart';
import 'package:kisou_app/providers/user_provider.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/repositories/travel_plan_repository.dart';
import 'package:kisou_app/screens/onboarding/login_screen.dart';
import 'package:kisou_app/services/auth_service.dart';
import 'package:kisou_app/services/travel_notification_service.dart';
import 'package:kisou_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('login with new user routes to onboarding state', () async {
    final authService = _LoginFakeAuthService(isNewUser: true);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).loginWithDevelopmentNewUser();

    final state = container.read(authProvider).requireValue;
    expect(state.isAuthenticated, isTrue);
    expect(state.isNewUser, isTrue);
    expect(authService.onboardingCompletedValue, isFalse);
  });

  test('login with existing user routes to home state', () async {
    final authService = _LoginFakeAuthService(isNewUser: false);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    authService.serverLogoutCallCount = 0;
    await container
        .read(authProvider.notifier)
        .loginWithDevelopmentExistingUser();

    final state = container.read(authProvider).requireValue;
    expect(state.isAuthenticated, isTrue);
    expect(state.isNewUser, isFalse);
    expect(authService.onboardingCompletedValue, isTrue);
  });

  test('login finalization failure revokes the new local session', () async {
    final authService = _LoginFakeAuthService(
      isNewUser: false,
      failOnboardingPersistence: true,
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    authService.serverLogoutCallCount = 0;
    await container
        .read(authProvider.notifier)
        .loginWithDevelopmentExistingUser();

    final failed = container.read(authProvider);
    expect(failed.isLoading, isFalse);
    expect(failed.hasError, isTrue);
    expect(authService.serverLogoutCallCount, 1);
    expect(authService.didClearTokens, isTrue);
    expect(authService.didClearOnboarding, isTrue);
  });

  test('onboarding completion routes to home state and stores flag', () async {
    final authService = _LoginFakeAuthService(isNewUser: true);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).completeOnboarding();

    final state = container.read(authProvider).requireValue;
    expect(state.isAuthenticated, isTrue);
    expect(state.isNewUser, isFalse);
    expect(authService.onboardingCompletedValue, isTrue);
  });

  test('switching accounts resets the selected shell tab', () async {
    final authService = _LoginFakeAuthService(isNewUser: false);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.read(shellTabProvider.notifier).setTab(ShellTab.profile);
    expect(container.read(shellTabProvider), ShellTab.profile);

    await container
        .read(authProvider.notifier)
        .loginWithDevelopmentExistingUser();

    expect(container.read(shellTabProvider), ShellTab.home);
  });

  test('full logout clears account-bound local data', () async {
    final authService = _LoginFakeAuthService(isNewUser: false);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container
        .read(authProvider.notifier)
        .loginWithDevelopmentExistingUser();
    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).requireValue.isAuthenticated, isFalse);
  });

  test(
    'account transition invalidates quota and reward but preserves UMP state',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false);
      final quotaBuilds = _BuildCounter();
      final rewardBuilds = _BuildCounter();
      final adsBuilds = _BuildCounter();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          travelPlanRepositoryProvider.overrideWithValue(
            MemoryTravelPlanRepository(),
          ),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
          outlookQuotaProvider.overrideWith(
            () => _CountingQuotaController(quotaBuilds),
          ),
          adRewardProvider.overrideWith(
            () => _CountingRewardController(rewardBuilds),
          ),
          adsProvider.overrideWith(() => _CountingAdsController(adsBuilds)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container
          .read(authProvider.notifier)
          .loginWithDevelopmentExistingUser();
      await container.read(outlookQuotaProvider.future);
      container.read(adRewardProvider);
      container.read(adsProvider);
      expect(quotaBuilds.value, 1);
      expect(rewardBuilds.value, 1);
      expect(adsBuilds.value, 1);

      await container.read(authProvider.notifier).logout();
      await container.read(outlookQuotaProvider.future);
      container.read(adRewardProvider);
      container.read(adsProvider);

      expect(quotaBuilds.value, 2);
      expect(rewardBuilds.value, 2);
      expect(adsBuilds.value, 1);
    },
  );

  test(
    'offline server logout still clears device-local account data',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false);
      final repository = MemoryTravelPlanRepository(
        now: () => DateTime.utc(2026, 7, 31),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container
          .read(authProvider.notifier)
          .loginWithDevelopmentExistingUser();
      await repository.create(
        TravelPlanDraft(
          cityCode: 'tokyo',
          departureAtUtc: DateTime.utc(2030, 8, 10),
          reminder: TravelReminder.none,
        ),
      );
      authService.failServerLogout = true;

      await container.read(authProvider.notifier).logout();

      expect(await repository.listVisible(), isEmpty);
      expect(
        container.read(authProvider).requireValue.isAuthenticated,
        isFalse,
      );
      expect(authService.didClearTokens, isTrue);
    },
  );

  testWidgets(
    'cleanup failure after server logout signs out and can be retried',
    (tester) async {
      final authService = _LoginFakeAuthService(isNewUser: false);
      final repository = MemoryTravelPlanRepository();
      final notifications = _FailingCancellationGateway();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container
          .read(authProvider.notifier)
          .loginWithDevelopmentExistingUser();
      await container
          .read(travelPlanProvider.notifier)
          .create(
            TravelPlanDraft(
              cityCode: 'tokyo',
              departureAtUtc: DateTime.utc(2030, 8, 10),
              reminder: TravelReminder.dayBefore,
            ),
            requestNotificationPermission: true,
          );
      notifications.failCancellation = true;

      await expectLater(
        container.read(authProvider.notifier).logout(),
        throwsA(isA<LocalAccountCleanupException>()),
      );

      final failed = container.read(authProvider).requireValue;
      expect(failed.isAuthenticated, isFalse);
      expect(failed.localCleanupRequired, isTrue);
      expect(failed.localCleanupScope, LocalCleanupScope.logout);
      expect(authService.didClearTokens, isTrue);
      expect(authService.didClearOnboarding, isTrue);
      expect(await repository.listVisible(), hasLength(1));
      expect(authService.localCleanupTransition, LocalCleanupTransition.logout);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.logoutLocalCleanupTitle), findsOneWidget);
      expect(find.text(AppStrings.logoutLocalCleanupFailed), findsOneWidget);
      expect(find.text(AppStrings.logoutLocalCleanupRetry), findsOneWidget);
      expect(
        find.text(AppStrings.accountDeleteLocalCleanupFailed),
        findsNothing,
      );
      expect(find.text(AppStrings.developerOptions), findsNothing);

      notifications.failCancellation = false;
      expect(
        await container.read(authProvider.notifier).retryLocalAccountCleanup(),
        isTrue,
      );
      expect(await repository.listAll(), isEmpty);
      expect(
        container.read(authProvider).requireValue.localCleanupRequired,
        isFalse,
      );
      expect(authService.didClearLocalAccountData, isFalse);
      expect(authService.localCleanupTransition, isNull);
    },
  );

  test(
    'persisted logout marker blocks a stale token after process restart',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false);
      final repository = MemoryTravelPlanRepository();
      final notifications = _FailingCancellationGateway();
      final overrides = [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(notifications),
      ];
      final firstContainer = ProviderContainer(overrides: overrides);

      await firstContainer.read(authProvider.future);
      await firstContainer
          .read(authProvider.notifier)
          .loginWithDevelopmentExistingUser();
      await firstContainer
          .read(travelPlanProvider.notifier)
          .create(_draftWithReminder(), requestNotificationPermission: true);
      notifications.failCancellation = true;
      authService.failTokenCleanup = true;

      await expectLater(
        firstContainer.read(authProvider.notifier).logout(),
        throwsA(isA<LocalAccountCleanupException>()),
      );
      expect(authService.hasTokenValue, isTrue);
      expect(authService.localCleanupTransition, LocalCleanupTransition.logout);
      expect(await repository.listVisible(), hasLength(1));
      firstContainer.dispose();

      notifications.failCancellation = false;
      authService.failTokenCleanup = false;
      final restartedContainer = ProviderContainer(overrides: overrides);
      addTearDown(restartedContainer.dispose);

      final restarted = await restartedContainer.read(authProvider.future);

      expect(restarted.isAuthenticated, isFalse);
      expect(authService.hasTokenValue, isFalse);
      expect(authService.localCleanupTransition, isNull);
      expect(await repository.listAll(), isEmpty);
    },
  );

  test(
    'interrupted server deletion resumes before local account cleanup',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false);
      final repository = MemoryTravelPlanRepository();
      final userService = _ControllableDeleteUserService(failOffline: true);
      final overrides = [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        userServiceProvider.overrideWithValue(userService),
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ];
      final firstContainer = ProviderContainer(overrides: overrides);
      await firstContainer.read(authProvider.future);
      await firstContainer
          .read(authProvider.notifier)
          .loginWithDevelopmentExistingUser();
      await repository.create(
        TravelPlanDraft(
          cityCode: 'tokyo',
          departureAtUtc: DateTime.utc(2030, 8, 10),
          reminder: TravelReminder.none,
        ),
      );

      await expectLater(
        firstContainer.read(authProvider.notifier).deleteAccount(),
        throwsA(isA<DioException>()),
      );
      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletionRequested,
      );
      expect(
        firstContainer.read(authProvider).requireValue.localCleanupScope,
        LocalCleanupScope.accountDeletionRequest,
      );
      expect(authService.hasTokenValue, isTrue);
      expect(await repository.listVisible(), hasLength(1));
      firstContainer.dispose();

      userService.failOffline = false;
      final restartedContainer = ProviderContainer(overrides: overrides);
      addTearDown(restartedContainer.dispose);
      final restarted = await restartedContainer.read(authProvider.future);

      expect(restarted.isAuthenticated, isFalse);
      expect(userService.deleteCalls, 2);
      expect(authService.hasTokenValue, isFalse);
      expect(authService.localCleanupTransition, isNull);
      expect(await repository.listAll(), isEmpty);
    },
  );

  test(
    'a lost successful deletion response accepts the deleted-user 401',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested;
      final repository = MemoryTravelPlanRepository();
      await repository.create(
        TravelPlanDraft(
          cityCode: 'tokyo',
          departureAtUtc: DateTime.utc(2030, 8, 10),
          reminder: TravelReminder.none,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(
            _ControllableDeleteUserService(responseStatus: 401),
          ),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final restarted = await container.read(authProvider.future);

      expect(restarted.isAuthenticated, isFalse);
      expect(authService.hasTokenValue, isFalse);
      expect(authService.localCleanupTransition, isNull);
      expect(await repository.listAll(), isEmpty);
    },
  );

  test('a deletion retry 404 keeps the server-request marker', () async {
    final authService = _LoginFakeAuthService(isNewUser: false)
      ..hasTokenValue = true
      ..localCleanupTransition =
          LocalCleanupTransition.accountDeletionRequested;
    final repository = MemoryTravelPlanRepository();
    await repository.create(
      TravelPlanDraft(
        cityCode: 'tokyo',
        departureAtUtc: DateTime.utc(2030, 8, 10),
        reminder: TravelReminder.none,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        userServiceProvider.overrideWithValue(
          _ControllableDeleteUserService(responseStatus: 404),
        ),
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final restarted = await container.read(authProvider.future);

    expect(
      restarted.localCleanupScope,
      LocalCleanupScope.accountDeletionRequest,
    );
    expect(authService.hasTokenValue, isTrue);
    expect(
      authService.localCleanupTransition,
      LocalCleanupTransition.accountDeletionRequested,
    );
    expect(await repository.listVisible(), hasLength(1));
  });

  test('auto anonymous login waits for stale travel cleanup', () async {
    final authService = _AutoLoginFakeAuthService();
    final repository = MemoryTravelPlanRepository();
    final notifications = _FailingCancellationGateway();
    await repository.create(
      TravelPlanDraft(
        cityCode: 'tokyo',
        departureAtUtc: DateTime.utc(2030, 8, 10),
        reminder: TravelReminder.none,
      ),
    );
    notifications.failCancellation = true;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(repository),
        travelNotificationGatewayProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);

    final blocked = await container.read(authProvider.future);

    expect(blocked.isAuthenticated, isFalse);
    expect(blocked.localCleanupScope, LocalCleanupScope.accountSwitch);
    expect(authService.anonymousLoginCount, 0);
    expect(await repository.listVisible(), hasLength(1));

    notifications.failCancellation = false;
    expect(
      await container.read(authProvider.notifier).retryLocalAccountCleanup(),
      isTrue,
    );
    container.invalidate(authProvider);
    final authenticated = await container.read(authProvider.future);

    expect(authenticated.isAuthenticated, isTrue);
    expect(authService.anonymousLoginCount, 1);
    expect(await repository.listAll(), isEmpty);
  });

  test('completed account deletion clears local data and signs out', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = _LoginFakeAuthService(isNewUser: false);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).completeAccountDeletion();

    expect(authService.didClearLocalAccountData, isTrue);
    expect(container.read(authProvider).requireValue.isAuthenticated, isFalse);
    expect(container.read(shellTabProvider), ShellTab.home);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test(
    'local cleanup failure signs out into a recoverable cleanup state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final authService = _LoginFakeAuthService(
        isNewUser: false,
        failLocalCleanup: true,
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          travelPlanRepositoryProvider.overrideWithValue(
            MemoryTravelPlanRepository(),
          ),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await expectLater(
        container.read(authProvider.notifier).completeAccountDeletion(),
        throwsA(isA<LocalAccountCleanupException>()),
      );

      final failedState = container.read(authProvider).requireValue;
      expect(failedState.isAuthenticated, isFalse);
      expect(failedState.localCleanupRequired, isTrue);
      expect(failedState.localCleanupScope, LocalCleanupScope.accountDeletion);
      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletion,
      );

      authService.failLocalCleanup = false;
      expect(
        await container.read(authProvider.notifier).retryLocalAccountCleanup(),
        isTrue,
      );
      expect(
        container.read(authProvider).requireValue.localCleanupRequired,
        isFalse,
      );
      expect(authService.localCleanupTransition, isNull);
    },
  );
}

class _LoginFakeAuthService extends AuthService {
  _LoginFakeAuthService({
    required this.isNewUser,
    this.failLocalCleanup = false,
    this.failOnboardingPersistence = false,
  });

  final bool isNewUser;
  bool failLocalCleanup;
  bool failOnboardingPersistence;
  bool failServerLogout = false;
  bool failTokenCleanup = false;
  bool hasTokenValue = false;
  bool onboardingCompletedValue = false;
  bool didClearLocalAccountData = false;
  bool didClearTokens = false;
  bool didClearOnboarding = false;
  int serverLogoutCallCount = 0;
  LocalCleanupTransition? localCleanupTransition;

  @override
  Future<void> clearKeychainOnFirstLaunch() async {}

  @override
  Future<LocalCleanupTransition?> readLocalCleanupTransition() async {
    return localCleanupTransition;
  }

  @override
  Future<void> markLocalCleanupTransition(
    LocalCleanupTransition transition,
  ) async {
    localCleanupTransition = transition;
  }

  @override
  Future<void> clearLocalCleanupTransition() async {
    localCleanupTransition = null;
  }

  @override
  Future<bool> hasToken() async {
    return hasTokenValue;
  }

  @override
  Future<bool> loginWithDevelopmentExistingUser({required Dio dio}) async {
    hasTokenValue = true;
    return isNewUser;
  }

  @override
  Future<bool> loginWithDevelopmentNewUser({required Dio dio}) async {
    hasTokenValue = true;
    return isNewUser;
  }

  @override
  Future<bool> loginAnonymous({required Dio dio}) async {
    throw const AuthException('offline');
  }

  @override
  Future<void> setOnboardingCompleted(bool isCompleted) async {
    if (failOnboardingPersistence) {
      throw StateError('onboarding persistence failed');
    }
    onboardingCompletedValue = isCompleted;
  }

  @override
  Future<void> clearLocalAccountData() async {
    if (failLocalCleanup) {
      throw StateError('local cleanup failed');
    }
    hasTokenValue = false;
    didClearLocalAccountData = true;
  }

  @override
  Future<void> logoutServer({required Dio dio}) async {
    serverLogoutCallCount++;
    if (failServerLogout) {
      throw StateError('server logout failed');
    }
  }

  @override
  Future<void> clearTokens() async {
    if (failTokenCleanup) {
      throw StateError('token cleanup failed');
    }
    hasTokenValue = false;
    didClearTokens = true;
  }

  @override
  Future<void> clearOnboardingCompleted() async {
    didClearOnboarding = true;
  }
}

class _AutoLoginFakeAuthService extends _LoginFakeAuthService {
  _AutoLoginFakeAuthService() : super(isNewUser: false);

  int anonymousLoginCount = 0;

  @override
  Future<bool> loginAnonymous({required Dio dio}) async {
    anonymousLoginCount++;
    return false;
  }
}

class _FailingCancellationGateway extends MemoryTravelNotificationGateway {
  bool failCancellation = false;

  @override
  Future<void> cancel(int notificationId) async {
    if (failCancellation) {
      throw StateError('notification cancellation failed');
    }
    await super.cancel(notificationId);
  }
}

class _ControllableDeleteUserService extends UserService {
  _ControllableDeleteUserService({
    this.failOffline = false,
    this.responseStatus,
  }) : super(Dio());

  bool failOffline;
  final int? responseStatus;
  int deleteCalls = 0;

  @override
  Future<void> deleteMe() async {
    deleteCalls++;
    final request = RequestOptions(path: '/users/me');
    if (failOffline) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    }
    if (responseStatus != null) {
      throw DioException(
        requestOptions: request,
        response: Response<void>(
          requestOptions: request,
          statusCode: responseStatus,
        ),
      );
    }
  }
}

class _BuildCounter {
  int value = 0;
}

class _CountingQuotaController extends OutlookQuotaController {
  _CountingQuotaController(this.counter);

  final _BuildCounter counter;

  @override
  Future<OutlookQuota> build() async {
    counter.value++;
    return OutlookQuota(
      date: '2026-07-31',
      freeLimit: 3,
      freeUsed: 0,
      freeRemaining: 3,
      rewardCredits: 0,
      totalRemaining: 3,
      resetsAt: DateTime.utc(2026, 7, 31, 15),
      adsAvailable: false,
    );
  }
}

class _CountingRewardController extends AdRewardController {
  _CountingRewardController(this.counter);

  final _BuildCounter counter;

  @override
  RewardFlowState build() {
    counter.value++;
    return const RewardFlowState.idle();
  }
}

class _CountingAdsController extends AdsController {
  _CountingAdsController(this.counter);

  final _BuildCounter counter;

  @override
  AdsState build() {
    counter.value++;
    return AdsState.initial(enabled: false);
  }
}

TravelPlanDraft _draftWithReminder() {
  return TravelPlanDraft(
    cityCode: 'tokyo',
    departureAtUtc: DateTime.utc(2030, 8, 10),
    reminder: TravelReminder.dayBefore,
  );
}
