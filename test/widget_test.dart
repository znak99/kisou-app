import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kisou_app/app.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/screens/onboarding/onboarding_screen.dart';
import 'package:kisou_app/services/auth_service.dart';

void main() {
  testWidgets('shows login screen for signed out users', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiHealthCheckEnabledProvider.overrideWithValue(false),
          authServiceProvider.overrideWithValue(
            _FakeAuthService(hasTokenValue: false),
          ),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.loginDescription), findsOneWidget);
    expect(find.text(AppStrings.appleLogin), findsOneWidget);
    expect(find.text(AppStrings.googleLogin), findsOneWidget);
    expect(find.text(AppStrings.developmentExistingLogin), findsOneWidget);
    expect(find.text(AppStrings.developmentNewLogin), findsOneWidget);
  });

  testWidgets(
    'shows onboarding when token exists but onboarding is incomplete',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiHealthCheckEnabledProvider.overrideWithValue(false),
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                hasTokenValue: true,
                onboardingCompletedValue: false,
              ),
            ),
          ],
          child: const KisouApp(),
        ),
      );
      await tester.pump();

      expect(find.text('1/5'), findsOneWidget);
      expect(find.text(AppStrings.nicknamePrompt), findsOneWidget);
    },
  );

  testWidgets('shows home when token exists and onboarding is complete', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiHealthCheckEnabledProvider.overrideWithValue(false),
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              hasTokenValue: true,
              onboardingCompletedValue: true,
            ),
          ),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.home), findsOneWidget);
    expect(find.text(AppStrings.logout), findsOneWidget);
  });

  testWidgets('onboarding nickname step blocks empty input and advances', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await tester.pump();

    expect(find.text('1/5'), findsOneWidget);
    expect(find.text(AppStrings.nicknamePrompt), findsOneWidget);

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    expect(nextButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'たろう');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
    await tester.pumpAndSettle();

    expect(find.text('2/5'), findsOneWidget);
    expect(find.text(AppStrings.genderPrompt), findsOneWidget);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required this.hasTokenValue,
    this.onboardingCompletedValue = false,
  });

  final bool hasTokenValue;
  final bool onboardingCompletedValue;

  @override
  Future<void> clearKeychainOnFirstLaunch() async {}

  @override
  Future<bool> hasToken() async {
    return hasTokenValue;
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    return onboardingCompletedValue;
  }
}
