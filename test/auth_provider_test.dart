import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/config/push_config.dart';
import 'package:kisou_app/models/push_notification.dart';
import 'package:kisou_app/providers/ad_reward_provider.dart';
import 'package:kisou_app/providers/ads_provider.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/providers/auth_provider.dart';
import 'package:kisou_app/providers/outlook_quota_provider.dart';
import 'package:kisou_app/providers/push_provider.dart';
import 'package:kisou_app/providers/shell_provider.dart';
import 'package:kisou_app/providers/theme_provider.dart';
import 'package:kisou_app/providers/travel_plan_provider.dart';
import 'package:kisou_app/providers/user_provider.dart';
import 'package:kisou_app/models/travel_plan.dart';
import 'package:kisou_app/models/account_deletion_status.dart';
import 'package:kisou_app/models/outlook_quota.dart';
import 'package:kisou_app/repositories/travel_plan_repository.dart';
import 'package:kisou_app/screens/onboarding/login_screen.dart';
import 'package:kisou_app/services/auth_service.dart';
import 'package:kisou_app/services/travel_notification_service.dart';
import 'package:kisou_app/services/user_service.dart';
import 'package:kisou_app/services/push_installation_store.dart';
import 'package:kisou_app/services/push_local_metadata.dart';
import 'package:kisou_app/services/push_messaging_gateway.dart';
import 'package:kisou_app/services/push_service.dart';
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

    expect(authService.didClearPendingAdRewardOperation, isTrue);
    expect(container.read(authProvider).requireValue.isAuthenticated, isFalse);
  });

  test(
    'malformed push receipts are reset only after logout closes push state',
    () async {
      SharedPreferences.setMockInitialValues({
        pushDeliveryReceiptStorageKey: '{corrupt',
      });
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..onboardingCompletedValue = true;
      final messaging = MemoryPushMessagingGateway();
      final pushManager = _BoundaryPushAccountManager();
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
          pushRuntimeEnabledProvider.overrideWithValue(true),
          pushMessagingGatewayProvider.overrideWithValue(messaging),
          pushAccountManagerProvider.overrideWithValue(pushManager),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await messaging.close();
      });

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).logout();

      final preferences = await SharedPreferences.getInstance();
      expect(pushManager.closeCalls, 1);
      expect(preferences.containsKey(pushDeliveryReceiptStorageKey), isFalse);
      expect(
        container.read(authProvider).requireValue.isAuthenticated,
        isFalse,
      );
    },
  );

  test(
    'interactive logout preserves auth and receipts until push close succeeds',
    () async {
      SharedPreferences.setMockInitialValues({
        pushDeliveryReceiptStorageKey: '{corrupt',
      });
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..onboardingCompletedValue = true;
      final messaging = MemoryPushMessagingGateway();
      final pushManager = _BoundaryPushAccountManager(failClose: true);
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
          pushRuntimeEnabledProvider.overrideWithValue(true),
          pushMessagingGatewayProvider.overrideWithValue(messaging),
          pushAccountManagerProvider.overrideWithValue(pushManager),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await messaging.close();
      });

      await container.read(authProvider.future);
      await expectLater(
        container.read(authProvider.notifier).logout(),
        throwsStateError,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(pushManager.closeCalls, 1);
      expect(preferences.getString(pushDeliveryReceiptStorageKey), '{corrupt');
      expect(container.read(authProvider).requireValue.isAuthenticated, isTrue);
      expect(authService.hasTokenValue, isTrue);
      expect(authService.onboardingCompletedValue, isTrue);
      expect(authService.didClearTokens, isFalse);
      expect(authService.didClearOnboarding, isFalse);

      pushManager.failClose = false;
      await container.read(authProvider.notifier).logout();

      expect(pushManager.closeCalls, 2);
      expect(authService.hasTokenValue, isFalse);
      expect(authService.onboardingCompletedValue, isFalse);
      expect(authService.didClearTokens, isTrue);
      expect(authService.didClearOnboarding, isTrue);
      expect(
        container.read(authProvider).requireValue.isAuthenticated,
        isFalse,
      );
    },
  );

  test(
    'startup interrupted transition preserves auth until push retry succeeds',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..onboardingCompletedValue = true
        ..localCleanupTransition = LocalCleanupTransition.accountSwitch;
      final messaging = MemoryPushMessagingGateway();
      final pushManager = _BoundaryPushAccountManager(failClose: true);
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
          pushRuntimeEnabledProvider.overrideWithValue(true),
          pushMessagingGatewayProvider.overrideWithValue(messaging),
          pushAccountManagerProvider.overrideWithValue(pushManager),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await messaging.close();
      });

      final blocked = await container.read(authProvider.future);

      expect(blocked.localCleanupScope, LocalCleanupScope.accountSwitch);
      expect(authService.hasTokenValue, isTrue);
      expect(authService.onboardingCompletedValue, isTrue);
      expect(authService.didClearTokens, isFalse);
      expect(authService.didClearOnboarding, isFalse);

      pushManager.failClose = false;
      expect(
        await container.read(authProvider.notifier).retryLocalAccountCleanup(),
        isTrue,
      );

      expect(authService.hasTokenValue, isFalse);
      expect(authService.onboardingCompletedValue, isFalse);
      expect(authService.didClearTokens, isTrue);
      expect(authService.didClearOnboarding, isTrue);
      expect(authService.localCleanupTransition, isNull);
    },
  );

  test(
    'login account switch preserves auth until push retry succeeds',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..onboardingCompletedValue = true;
      final messaging = MemoryPushMessagingGateway();
      final pushManager = _BoundaryPushAccountManager(failClose: true);
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
          pushRuntimeEnabledProvider.overrideWithValue(true),
          pushMessagingGatewayProvider.overrideWithValue(messaging),
          pushAccountManagerProvider.overrideWithValue(pushManager),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await messaging.close();
      });

      expect(
        (await container.read(authProvider.future)).isAuthenticated,
        isTrue,
      );

      await container
          .read(authProvider.notifier)
          .loginWithDevelopmentExistingUser();

      final blocked = container.read(authProvider).requireValue;
      expect(blocked.localCleanupScope, LocalCleanupScope.accountSwitch);
      expect(authService.hasTokenValue, isTrue);
      expect(authService.onboardingCompletedValue, isTrue);
      expect(authService.didClearTokens, isFalse);
      expect(authService.didClearOnboarding, isFalse);

      pushManager.failClose = false;
      expect(
        await container.read(authProvider.notifier).retryLocalAccountCleanup(),
        isTrue,
      );

      expect(authService.hasTokenValue, isFalse);
      expect(authService.onboardingCompletedValue, isFalse);
      expect(authService.didClearTokens, isTrue);
      expect(authService.didClearOnboarding, isTrue);
      expect(authService.localCleanupTransition, isNull);
    },
  );

  test('cleanup retry preserves auth when its push close fails', () async {
    final authService = _LoginFakeAuthService(isNewUser: false)
      ..hasTokenValue = true
      ..onboardingCompletedValue = true
      ..localCleanupTransition = LocalCleanupTransition.accountSwitch;
    final messaging = MemoryPushMessagingGateway();
    final pushManager = _BoundaryPushAccountManager(failClose: true);
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
        pushRuntimeEnabledProvider.overrideWithValue(true),
        pushMessagingGatewayProvider.overrideWithValue(messaging),
        pushAccountManagerProvider.overrideWithValue(pushManager),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await messaging.close();
    });

    final blocked = await container.read(authProvider.future);
    expect(blocked.localCleanupScope, LocalCleanupScope.accountSwitch);
    expect(authService.hasTokenValue, isTrue);
    expect(authService.onboardingCompletedValue, isTrue);

    expect(
      await container.read(authProvider.notifier).retryLocalAccountCleanup(),
      isFalse,
    );

    expect(authService.hasTokenValue, isTrue);
    expect(authService.onboardingCompletedValue, isTrue);
    expect(authService.didClearTokens, isFalse);
    expect(authService.didClearOnboarding, isFalse);

    pushManager.failClose = false;
    expect(
      await container.read(authProvider.notifier).retryLocalAccountCleanup(),
      isTrue,
    );

    expect(authService.hasTokenValue, isFalse);
    expect(authService.onboardingCompletedValue, isFalse);
    expect(authService.didClearTokens, isTrue);
    expect(authService.didClearOnboarding, isTrue);
    expect(authService.localCleanupTransition, isNull);
  });

  test('session expiry preserves auth until push retry succeeds', () async {
    final authService = _LoginFakeAuthService(isNewUser: false)
      ..hasTokenValue = true
      ..onboardingCompletedValue = true;
    final messaging = MemoryPushMessagingGateway();
    final pushManager = _BoundaryPushAccountManager(failClose: true);
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
        pushRuntimeEnabledProvider.overrideWithValue(true),
        pushMessagingGatewayProvider.overrideWithValue(messaging),
        pushAccountManagerProvider.overrideWithValue(pushManager),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await messaging.close();
    });

    expect((await container.read(authProvider.future)).isAuthenticated, isTrue);

    await container.read(authProvider.notifier).expireSession();

    final blocked = container.read(authProvider).requireValue;
    expect(blocked.localCleanupScope, LocalCleanupScope.accountSwitch);
    expect(authService.hasTokenValue, isTrue);
    expect(authService.onboardingCompletedValue, isTrue);
    expect(authService.didClearTokens, isFalse);
    expect(authService.didClearOnboarding, isFalse);

    pushManager.failClose = false;
    expect(
      await container.read(authProvider.notifier).retryLocalAccountCleanup(),
      isTrue,
    );

    expect(authService.hasTokenValue, isFalse);
    expect(authService.onboardingCompletedValue, isFalse);
    expect(authService.didClearTokens, isTrue);
    expect(authService.didClearOnboarding, isTrue);
    expect(authService.localCleanupTransition, isNull);
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
      authService.didClearTokens = false;
      authService.didClearOnboarding = false;
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
      expect(authService.hasTokenValue, isTrue);
      expect(authService.onboardingCompletedValue, isTrue);
      expect(authService.didClearTokens, isFalse);
      expect(authService.didClearOnboarding, isFalse);
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
      expect(authService.didClearTokens, isTrue);
      expect(authService.didClearOnboarding, isTrue);
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
        throwsA(isA<AccountDeletionConfirmationException>()),
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
    'a lost successful deletion response requires a completed receipt',
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
            _ControllableDeleteUserService(
              responseStatus: 401,
              receiptCompleted: true,
            ),
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

  test(
    'expireSession never downgrades a persisted deletion request marker',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true;
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
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      await authService.markAccountDeletionRequested(
        '11111111-1111-4111-8111-111111111111',
      );

      await container.read(authProvider.notifier).expireSession();

      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletionRequested,
      );
      expect(
        authService.accountDeletionIdempotencyKey,
        '11111111-1111-4111-8111-111111111111',
      );
      expect(
        container.read(authProvider).requireValue.localCleanupScope,
        LocalCleanupScope.accountDeletionRequest,
      );
      expect(await repository.listVisible(), hasLength(1));
      expect(authService.didClearTokens, isFalse);
    },
  );

  test(
    'queued session expiry cannot overtake the atomic deletion marker write',
    () async {
      final markerStarted = Completer<void>();
      final markerGate = Completer<void>();
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..markDeletionRequestedStarted = markerStarted
        ..markDeletionRequestedGate = markerGate.future;
      final userService = _ControllableDeleteUserService(failOffline: true);
      final repository = MemoryTravelPlanRepository();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(userService),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final deleting = container.read(authProvider.notifier).deleteAccount();
      await markerStarted.future;
      await container.read(authProvider.notifier).expireSession();

      expect(container.read(authProvider).requireValue.isAuthenticated, isTrue);
      expect(
        container.read(authProvider).requireValue.localCleanupScope,
        isNull,
      );
      expect(authService.localCleanupTransition, isNull);

      markerGate.complete();
      await expectLater(
        deleting,
        throwsA(isA<AccountDeletionConfirmationException>()),
      );

      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletionRequested,
      );
      expect(
        container.read(authProvider).requireValue.localCleanupScope,
        LocalCleanupScope.accountDeletionRequest,
      );
      expect(authService.didClearTokens, isFalse);
    },
  );

  test(
    'concurrent delete taps share one UUID and one server request',
    () async {
      final deleteGate = Completer<void>();
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true;
      final userService = _ControllableDeleteUserService(
        deleteGate: deleteGate.future,
      );
      var generatedKeys = 0;
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(userService),
          accountDeletionIdempotencyKeyFactoryProvider.overrideWithValue(() {
            generatedKeys++;
            return '11111111-1111-4111-8111-111111111111';
          }),
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
      final controller = container.read(authProvider.notifier);

      final first = controller.deleteAccount();
      final second = controller.deleteAccount();
      await Future<void>.delayed(Duration.zero);
      expect(userService.deleteCalls, 1);
      deleteGate.complete();
      await Future.wait([first, second]);

      expect(generatedKeys, 1);
      expect(userService.idempotencyKeys, [
        '11111111-1111-4111-8111-111111111111',
      ]);
    },
  );

  test('secure deletion marker failure prevents the DELETE request', () async {
    final authService = _LoginFakeAuthService(isNewUser: false)
      ..hasTokenValue = true
      ..failMarkDeletionRequested = true;
    final userService = _ControllableDeleteUserService();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        userServiceProvider.overrideWithValue(userService),
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
      container.read(authProvider.notifier).deleteAccount(),
      throwsStateError,
    );

    expect(userService.deleteCalls, 0);
    expect(authService.localCleanupTransition, isNull);
  });

  testWidgets(
    'unrelated 401 and missing receipt preserve data and show recovery',
    (tester) async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = true
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested
        ..accountDeletionIdempotencyKey =
            '11111111-1111-4111-8111-111111111111';
      final repository = MemoryTravelPlanRepository();
      await repository.create(
        TravelPlanDraft(
          cityCode: 'tokyo',
          departureAtUtc: DateTime.utc(2030, 8, 10),
          reminder: TravelReminder.none,
        ),
      );
      late final _ControllableDeleteUserService userService;
      userService = _ControllableDeleteUserService(
        responseStatus: 401,
        onDelete: () => authService.hasTokenValue = false,
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(userService),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final recovered = await container.read(authProvider.future);
      expect(
        recovered.accountDeletionRecoveryKind,
        AccountDeletionRecoveryKind.authenticationRequired,
      );
      expect(recovered.canDiscardUnconfirmedAccountData, isTrue);
      expect(await repository.listVisible(), hasLength(1));
      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletionRequested,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.accountDeleteRequestAuthenticationRequired),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.accountDeleteRequestDiscardLocalOnly),
        findsOneWidget,
      );
      expect(find.text(AppStrings.developerOptions), findsNothing);

      await tester.ensureVisible(
        find.text(AppStrings.accountDeleteRequestDiscardLocalOnly),
      );
      await tester.tap(
        find.text(AppStrings.accountDeleteRequestDiscardLocalOnly),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.accountDeleteRequestDiscardLocalTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.accountDeleteRequestDiscardLocalBody),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.accountDeleteRequestDiscardLocalConfirm),
        findsOneWidget,
      );
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      expect(userService.deleteCalls, 1);
      expect(await repository.listVisible(), hasLength(1));
      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletionRequested,
      );
    },
  );

  test(
    'explicit local-only discard cleans account stores without another DELETE',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = false
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested
        ..accountDeletionIdempotencyKey =
            '11111111-1111-4111-8111-111111111111';
      final repository = MemoryTravelPlanRepository();
      await repository.create(
        TravelPlanDraft(
          cityCode: 'tokyo',
          departureAtUtc: DateTime.utc(2030, 8, 10),
          reminder: TravelReminder.none,
        ),
      );
      final userService = _ControllableDeleteUserService();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(userService),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final blocked = await container.read(authProvider.future);
      expect(blocked.canDiscardUnconfirmedAccountData, isTrue);
      expect(userService.deleteCalls, 0);

      expect(
        await container
            .read(authProvider.notifier)
            .discardUnconfirmedAccountData(),
        isTrue,
      );

      expect(userService.deleteCalls, 0);
      expect(await repository.listAll(), isEmpty);
      expect(authService.didClearPendingAdRewardOperation, isTrue);
      expect(authService.didClearTokens, isTrue);
      expect(authService.didClearOnboarding, isTrue);
      expect(authService.didClearLocalAccountData, isTrue);
      expect(authService.localCleanupTransition, isNull);
      expect(
        container.read(authProvider).requireValue.localCleanupScope,
        isNull,
      );
    },
  );

  testWidgets(
    'confirmed local-only discard starts a new anonymous account automatically',
    (tester) async {
      final authService = _AutoLoginFakeAuthService()
        ..hasTokenValue = false
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested
        ..accountDeletionIdempotencyKey =
            '11111111-1111-4111-8111-111111111111';
      final userService = _ControllableDeleteUserService();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(userService),
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(AppStrings.accountDeleteRequestDiscardLocalOnly),
      );
      await tester.tap(
        find.text(AppStrings.accountDeleteRequestDiscardLocalOnly),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppStrings.accountDeleteRequestDiscardLocalConfirm),
      );
      await tester.pumpAndSettle();

      expect(container.read(authProvider).requireValue.isAuthenticated, isTrue);
      expect(authService.anonymousLoginCount, 1);
      expect(authService.didClearLocalAccountData, isTrue);
      expect(authService.localCleanupTransition, isNull);
      expect(userService.deleteCalls, 0);
    },
  );

  test(
    'local-only discard marker failure preserves deletion recovery and data',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = false
        ..failUnconfirmedDiscardMarker = true
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested
        ..accountDeletionIdempotencyKey =
            '11111111-1111-4111-8111-111111111111';
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
            _ControllableDeleteUserService(),
          ),
          travelPlanRepositoryProvider.overrideWithValue(repository),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        (await container.read(
          authProvider.future,
        )).canDiscardUnconfirmedAccountData,
        isTrue,
      );
      expect(
        await container
            .read(authProvider.notifier)
            .discardUnconfirmedAccountData(),
        isFalse,
      );

      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.accountDeletionRequested,
      );
      expect(await repository.listVisible(), hasLength(1));
    },
  );

  test(
    'failed local-only cleanup resumes from its dedicated marker after restart',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = false
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested
        ..accountDeletionIdempotencyKey =
            '11111111-1111-4111-8111-111111111111';
      authService.failLocalCleanup = true;
      final overrides = [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
        userServiceProvider.overrideWithValue(_ControllableDeleteUserService()),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ];
      final first = ProviderContainer(overrides: overrides);

      expect(
        (await first.read(
          authProvider.future,
        )).canDiscardUnconfirmedAccountData,
        isTrue,
      );
      expect(
        await first.read(authProvider.notifier).discardUnconfirmedAccountData(),
        isFalse,
      );
      expect(
        first.read(authProvider).requireValue.localCleanupScope,
        LocalCleanupScope.unconfirmedAccountDiscard,
      );
      expect(
        authService.localCleanupTransition,
        LocalCleanupTransition.unconfirmedAccountDiscard,
      );
      first.dispose();

      authService.failLocalCleanup = false;
      final restarted = ProviderContainer(overrides: overrides);
      addTearDown(restarted.dispose);
      final recovered = await restarted.read(authProvider.future);

      expect(recovered.localCleanupScope, isNull);
      expect(authService.localCleanupTransition, isNull);
      expect(authService.didClearLocalAccountData, isTrue);
    },
  );

  test(
    'strict guest restore retries DELETE with the persisted UUID only',
    () async {
      final authService = _LoginFakeAuthService(isNewUser: false)
        ..hasTokenValue = false
        ..strictAnonymousRestoreSucceeds = true
        ..localCleanupTransition =
            LocalCleanupTransition.accountDeletionRequested
        ..accountDeletionIdempotencyKey =
            '11111111-1111-4111-8111-111111111111';
      final userService = _ControllableDeleteUserService();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          apiClientProvider.overrideWithValue(Dio()),
          userServiceProvider.overrideWithValue(userService),
          travelPlanRepositoryProvider.overrideWithValue(
            MemoryTravelPlanRepository(),
          ),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final recovered = await container.read(authProvider.future);

      expect(recovered.isAuthenticated, isFalse);
      expect(userService.idempotencyKeys, [
        '11111111-1111-4111-8111-111111111111',
      ]);
      expect(authService.didClearLocalAccountData, isTrue);
      expect(authService.localCleanupTransition, isNull);
    },
  );

  test(
    'status 429, server error, and parse failure all preserve local data',
    () async {
      final statusErrors = <Object>[
        _dioStatusError(429),
        _dioStatusError(503),
        const FormatException('malformed receipt'),
      ];
      for (final statusError in statusErrors) {
        final authService = _LoginFakeAuthService(isNewUser: false)
          ..hasTokenValue = true
          ..localCleanupTransition =
              LocalCleanupTransition.accountDeletionRequested
          ..accountDeletionIdempotencyKey =
              '11111111-1111-4111-8111-111111111111';
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
              _ControllableDeleteUserService(
                failOffline: true,
                statusError: statusError,
              ),
            ),
            travelPlanRepositoryProvider.overrideWithValue(repository),
            travelNotificationGatewayProvider.overrideWithValue(
              MemoryTravelNotificationGateway(),
            ),
          ],
        );

        final recovered = await container.read(authProvider.future);

        expect(
          recovered.localCleanupScope,
          LocalCleanupScope.accountDeletionRequest,
        );
        expect(recovered.canDiscardUnconfirmedAccountData, isFalse);
        expect(await repository.listVisible(), hasLength(1));
        expect(
          authService.localCleanupTransition,
          LocalCleanupTransition.accountDeletionRequested,
        );
        container.dispose();
      }
    },
  );

  test(
    'unavailable receipt never enables local-only discard without a session',
    () async {
      final statusErrors = <Object>[
        DioException(
          requestOptions: RequestOptions(path: '/account-deletion/status'),
          type: DioExceptionType.connectionError,
        ),
        _dioStatusError(429),
        _dioStatusError(503),
        const FormatException('malformed receipt'),
      ];
      for (final statusError in statusErrors) {
        final authService = _LoginFakeAuthService(isNewUser: false)
          ..hasTokenValue = false
          ..localCleanupTransition =
              LocalCleanupTransition.accountDeletionRequested
          ..accountDeletionIdempotencyKey =
              '11111111-1111-4111-8111-111111111111';
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            apiClientProvider.overrideWithValue(Dio()),
            userServiceProvider.overrideWithValue(
              _ControllableDeleteUserService(statusError: statusError),
            ),
            travelPlanRepositoryProvider.overrideWithValue(
              MemoryTravelPlanRepository(),
            ),
            travelNotificationGatewayProvider.overrideWithValue(
              MemoryTravelNotificationGateway(),
            ),
          ],
        );

        final recovered = await container.read(authProvider.future);

        expect(
          recovered.accountDeletionRecoveryKind,
          AccountDeletionRecoveryKind.authenticationRequired,
        );
        expect(recovered.canDiscardUnconfirmedAccountData, isFalse);
        expect(
          authService.localCleanupTransition,
          LocalCleanupTransition.accountDeletionRequested,
        );
        container.dispose();
      }
    },
  );
}

DioException _dioStatusError(int statusCode) {
  final request = RequestOptions(path: '/account-deletion/status');
  return DioException(
    requestOptions: request,
    response: Response<void>(requestOptions: request, statusCode: statusCode),
    type: DioExceptionType.badResponse,
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
  bool didClearPendingAdRewardOperation = false;
  String? accountDeletionIdempotencyKey;
  bool strictAnonymousRestoreSucceeds = false;
  bool failMarkDeletionRequested = false;
  bool failUnconfirmedDiscardMarker = false;
  Completer<void>? markDeletionRequestedStarted;
  Future<void>? markDeletionRequestedGate;
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
    if (transition == LocalCleanupTransition.unconfirmedAccountDiscard &&
        failUnconfirmedDiscardMarker) {
      throw StateError('unconfirmed discard marker write failed');
    }
    localCleanupTransition = transition;
  }

  @override
  Future<void> markAccountDeletionRequested(String idempotencyKey) async {
    markDeletionRequestedStarted?.complete();
    if (markDeletionRequestedGate case final gate?) {
      await gate;
    }
    if (failMarkDeletionRequested) {
      throw StateError('secure marker write failed');
    }
    localCleanupTransition = LocalCleanupTransition.accountDeletionRequested;
    accountDeletionIdempotencyKey = idempotencyKey;
  }

  @override
  Future<void> markAccountDeletionConfirmed(String idempotencyKey) async {
    localCleanupTransition = LocalCleanupTransition.accountDeletion;
    accountDeletionIdempotencyKey = idempotencyKey;
  }

  @override
  Future<String?> readAccountDeletionRequestIdempotencyKey() async {
    return accountDeletionIdempotencyKey;
  }

  @override
  Future<void> clearLocalCleanupTransition() async {
    localCleanupTransition = null;
    accountDeletionIdempotencyKey = null;
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
  Future<bool> restoreAnonymousSessionForDeletion({required Dio dio}) async {
    if (strictAnonymousRestoreSucceeds) {
      hasTokenValue = true;
    }
    return strictAnonymousRestoreSucceeds;
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
    onboardingCompletedValue = false;
    didClearLocalAccountData = true;
    didClearTokens = true;
    didClearOnboarding = true;
    didClearPendingAdRewardOperation = true;
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
    onboardingCompletedValue = false;
    didClearOnboarding = true;
  }

  @override
  Future<void> clearPendingAdRewardOperation() async {
    didClearPendingAdRewardOperation = true;
  }
}

class _BoundaryPushAccountManager extends PushAccountManager {
  _BoundaryPushAccountManager({this.failClose = false})
    : super(
        store: PushInstallationStore(),
        messaging: const DisabledPushMessagingGateway(),
        api: _UnusedPushApi(),
        platform: KisouPushPlatform.android,
        appVersionFactory: _unusedAppVersion,
      );

  bool failClose;
  int closeCalls = 0;

  @override
  Future<PushInstallationSnapshot> closeAccount({
    bool suppressAuthRecovery = true,
  }) async {
    closeCalls++;
    if (failClose) {
      throw StateError('push close failed');
    }
    return PushInstallationSnapshot(
      record: PushInstallationRecord.create(
        '123e4567-e89b-42d3-a456-426614174000',
      ),
      accountGeneration: closeCalls,
    );
  }
}

class _UnusedPushApi implements PushApiGateway {
  @override
  Future<PushPreferences> getPreferences() async => PushPreferences.defaults;

  @override
  Future<void> registerDevice({
    required String installationId,
    required int clientRevision,
    required KisouPushPlatform platform,
    required String fcmToken,
    required String appVersion,
  }) async {}

  @override
  Future<void> unregisterDevice({
    required String installationId,
    required int clientRevision,
    bool suppressAuthRecovery = false,
  }) async {}

  @override
  Future<PushPreferences> updatePreferences(PushPreferences preferences) async {
    return preferences;
  }
}

Future<String> _unusedAppVersion() async => '1.0.0+1';

class _AutoLoginFakeAuthService extends _LoginFakeAuthService {
  _AutoLoginFakeAuthService() : super(isNewUser: false);

  int anonymousLoginCount = 0;

  @override
  Future<bool> loginAnonymous({required Dio dio}) async {
    anonymousLoginCount++;
    hasTokenValue = true;
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
    this.receiptCompleted = false,
    this.statusError,
    this.onDelete,
    this.deleteGate,
  }) : super(Dio());

  bool failOffline;
  final int? responseStatus;
  bool receiptCompleted;
  final Object? statusError;
  final void Function()? onDelete;
  final Future<void>? deleteGate;
  int deleteCalls = 0;
  final List<String> idempotencyKeys = [];

  @override
  Future<void> deleteMe({required String idempotencyKey}) async {
    deleteCalls++;
    idempotencyKeys.add(idempotencyKey);
    onDelete?.call();
    if (deleteGate case final gate?) {
      await gate;
    }
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
    receiptCompleted = true;
  }

  @override
  Future<AccountDeletionStatus?> getDeletionStatus({
    required String idempotencyKey,
  }) async {
    if (statusError case final error?) {
      throw error;
    }
    if (!receiptCompleted) {
      return null;
    }
    return AccountDeletionStatus(
      completedAt: DateTime.utc(2026, 7, 31),
      expiresAt: DateTime.utc(2026, 8, 1),
    );
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
