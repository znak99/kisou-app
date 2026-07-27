import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/providers/auth_provider.dart';
import 'package:kisou_app/providers/shell_provider.dart';
import 'package:kisou_app/services/auth_service.dart';

void main() {
  test('login with new user routes to onboarding state', () async {
    final authService = _LoginFakeAuthService(isNewUser: true);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
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
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container
        .read(authProvider.notifier)
        .loginWithDevelopmentExistingUser();

    final state = container.read(authProvider).requireValue;
    expect(state.isAuthenticated, isTrue);
    expect(state.isNewUser, isFalse);
    expect(authService.onboardingCompletedValue, isTrue);
  });

  test('onboarding completion routes to home state and stores flag', () async {
    final authService = _LoginFakeAuthService(isNewUser: true);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(Dio()),
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
}

class _LoginFakeAuthService extends AuthService {
  _LoginFakeAuthService({required this.isNewUser});

  final bool isNewUser;
  bool onboardingCompletedValue = false;

  @override
  Future<void> clearKeychainOnFirstLaunch() async {}

  @override
  Future<bool> hasToken() async {
    return false;
  }

  @override
  Future<bool> loginWithDevelopmentExistingUser({required Dio dio}) async {
    return isNewUser;
  }

  @override
  Future<bool> loginWithDevelopmentNewUser({required Dio dio}) async {
    return isNewUser;
  }

  @override
  Future<void> setOnboardingCompleted(bool isCompleted) async {
    onboardingCompletedValue = isCompleted;
  }
}
