import 'package:dio/dio.dart';
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
          apiClientProvider.overrideWithValue(_createAppDio()),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('たろうさん、${AppStrings.todayClothing}'), findsOneWidget);
    expect(find.text('📍 東京'), findsOneWidget);
    expect(find.text(AppStrings.bestRecommendation), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.today), findsOneWidget);
    expect(find.text(AppStrings.yesterday), findsOneWidget);
    expect(find.text(AppStrings.twoDaysAgo), findsOneWidget);
    expect(find.text('昨日より3°高い'), findsOneWidget);
    expect(find.text(AppStrings.feedbackPrompt), findsOneWidget);
    expect(find.text(AppStrings.feedbackButton), findsOneWidget);

    await tester.tap(find.text(AppStrings.feedbackButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.feedbackClothingTitle), findsOneWidget);
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

Dio _createAppDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        switch (options.path) {
          case '/users/me':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'id': '00000000-0000-0000-0000-000000000001',
                  'nickname': 'たろう',
                  'gender': 'unspecified',
                  'cold_sensitivity': 'normal',
                  'heat_sensitivity': 'normal',
                  'offset_value': 0,
                  'departure_time': '09:00:00',
                  'return_time': '18:00:00',
                  'latitude': 35.6812,
                  'longitude': 139.7671,
                  'region_name': '東京',
                  'created_at': '2026-05-06T00:00:00Z',
                  'updated_at': '2026-05-06T00:00:00Z',
                },
              ),
            );
          case '/home':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'date': '2026-05-06',
                  'recommendations': [
                    {
                      'rank': 1,
                      'top': 'SHORT_SLEEVE',
                      'bottom': 'LONG_PANTS',
                      'outer': 'LIGHT_OUTER',
                    },
                    {
                      'rank': 2,
                      'top': 'LONG_SLEEVE',
                      'bottom': 'LONG_PANTS',
                      'outer': null,
                    },
                    {
                      'rank': 3,
                      'top': 'THIN_LONG',
                      'bottom': 'SKIRT',
                      'outer': 'CARDIGAN',
                    },
                  ],
                  'weather_comparison': {
                    'today': _weather(tempHigh: 22, tempLow: 14),
                    'yesterday': _weather(tempHigh: 19, tempLow: 12),
                    'two_days_ago': _weather(tempHigh: 24, tempLow: 16),
                  },
                },
              ),
            );
          case '/feedback/today':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'exists': false, 'feedback': null},
              ),
            );
          default:
            handler.reject(DioException(requestOptions: options));
        }
      },
    ),
  );
  return dio;
}

Map<String, dynamic> _weather({
  required double tempHigh,
  required double tempLow,
}) {
  return {
    'temp_high': tempHigh,
    'temp_low': tempLow,
    'feels_like_high': tempHigh,
    'feels_like_low': tempLow,
    'humidity_avg': 55,
    'wind_speed_avg': 2.0,
    'precipitation_chance_max': null,
    'wbgt_max': null,
  };
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
