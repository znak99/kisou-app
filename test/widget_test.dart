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
          authServiceProvider.overrideWithValue(
            _FakeAuthService(hasTokenValue: false),
          ),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.loginDescription), findsOneWidget);
    // Anonymous-only MVP: social sign-in is hidden; a retry button is offered.
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.developmentExistingLogin), findsOneWidget);
    expect(find.text(AppStrings.developmentNewLogin), findsOneWidget);
  });

  testWidgets(
    'shows onboarding when token exists but onboarding is incomplete',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
      await pumpPastSplash(tester);

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
    await pumpPastSplash(tester);

    expect(find.text('たろうさん、${AppStrings.todayClothing}'), findsOneWidget);
    expect(find.text('東京'), findsOneWidget);
    expect(find.text(AppStrings.bestRecommendation), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.today), findsOneWidget);
    expect(find.text(AppStrings.yesterday), findsOneWidget);
    expect(find.text(AppStrings.twoDaysAgo), findsOneWidget);
    expect(find.text('昨日より3°'), findsOneWidget);
    // The feedback action lives in the shared top toolbar.
    expect(find.text(AppStrings.feedbackButton), findsOneWidget);

    await tester.tap(find.text(AppStrings.feedbackButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.feedbackClothingTitle), findsOneWidget);
  });

  testWidgets('shows complete settings list from home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    await pumpPastSplash(tester);

    // Settings now live under the "メニュー" bottom-nav tab.
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();

    // Top of the list is visible immediately.
    expect(find.text(AppStrings.nicknameSetting), findsOneWidget);
    expect(find.text(AppStrings.genderSetting), findsOneWidget);

    // The account actions sit at the bottom of the (lazy) list.
    await tester.scrollUntilVisible(
      find.text(AppStrings.accountDelete),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.logout), findsOneWidget);
    expect(find.text(AppStrings.accountDelete), findsOneWidget);
  });

  testWidgets('shows timeout error on home load failure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              hasTokenValue: true,
              onboardingCompletedValue: true,
            ),
          ),
          apiClientProvider.overrideWithValue(
            _createHomeErrorDio(DioExceptionType.connectionTimeout),
          ),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    // 서버에 못 닿으면 스플래시에서 재시도한다(_kHomeRetryLimit 회).
    expect(find.text(AppStrings.splashLoading), findsOneWidget);
    expect(find.text(AppStrings.timeoutError), findsNothing);

    // 상한을 넘기면 홈으로 넘겨 홈의 에러 UI가 처리한다.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.timeoutError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('shows location settings action when location is missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              hasTokenValue: true,
              onboardingCompletedValue: true,
            ),
          ),
          apiClientProvider.overrideWithValue(_createLocationMissingDio()),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);

    expect(find.text(AppStrings.locationMissing), findsOneWidget);
    expect(find.text(AppStrings.openSettings), findsOneWidget);
  });

  testWidgets('session expiration returns to login', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          _FakeAuthService(hasTokenValue: true, onboardingCompletedValue: true),
        ),
        apiClientProvider.overrideWithValue(_createAppDio()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KisouApp()),
    );
    await pumpPastSplash(tester);
    expect(find.text('たろうさん、${AppStrings.todayClothing}'), findsOneWidget);

    container.read(authRequiredProvider.notifier).requireAuth();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginDescription), findsOneWidget);
    expect(find.text(AppStrings.sessionExpired), findsOneWidget);
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

  testWidgets('재방문 사용자: 홈 응답이 늦으면 스플래시가 계속 뜨고 안내 문구가 보인다', (
    WidgetTester tester,
  ) async {
    // 토큰이 있으면 인증은 서버 없이 즉시 끝난다. 그래도 첫 홈 로드를 기다려야 한다.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              hasTokenValue: true,
              onboardingCompletedValue: true,
            ),
          ),
          apiClientProvider.overrideWithValue(_createHangingDio()),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pump();

    // 최소 시간 전: 스플래시만, 문구 없음
    expect(find.text(AppStrings.splashLoading), findsNothing);

    // 최소 시간 경과 후에도 홈이 안 오면 문구가 뜬다 (pumpAndSettle 금지: 점 타이머가 계속 돈다)
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(AppStrings.splashLoading), findsOneWidget);
    expect(find.text(AppStrings.todayClothing), findsNothing); // 홈으로 안 넘어감

    // 위젯 정리(점 타이머 해제)
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('서버가 죽어 있으면 스플래시에서 재시도하고, 살아나면 자동으로 홈에 들어간다', (
    WidgetTester tester,
  ) async {
    var serverDown = true;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (serverDown) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          _resolveAppRequest(options, handler);
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              hasTokenValue: true,
              onboardingCompletedValue: true,
            ),
          ),
          apiClientProvider.overrideWithValue(dio),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    // 연결 거부는 즉시 실패하지만, 홈으로 떨어뜨리지 않고 스플래시에서 기다린다.
    expect(find.text(AppStrings.splashLoading), findsOneWidget);

    // 서버가 살아나면 다음 재시도에서 홈으로 진입한다.
    serverDown = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.splashLoading), findsNothing);
    expect(find.text('たろうさん、${AppStrings.todayClothing}'), findsOneWidget);
  });
}

/// KisouApp 은 시작 시 최소 1.5초 스플래시를 띄운다(app.dart의 _kMinSplash).
/// 실제 화면을 검증하려면 그 시간을 넘겨야 한다.
Future<void> pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

/// 요청을 영원히 붙잡아 두는 Dio — provider 를 loading 상태에 묶어 둔다.
Dio _createHangingDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        /* 응답하지 않음 */
      },
    ),
  );
  return dio;
}

Dio _createAppDio() {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: _resolveAppRequest));
  return dio;
}

/// 정상 응답하는 앱 백엔드 목. 서버 상태를 바꿔가며 쓰는 테스트에서 재사용한다.
void _resolveAppRequest(
  RequestOptions options,
  RequestInterceptorHandler handler,
) {
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
}

Dio _createHomeErrorDio(DioExceptionType type) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        switch (options.path) {
          case '/users/me':
          case '/feedback/today':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: options.path == '/users/me'
                    ? _userJson()
                    : {'exists': false, 'feedback': null},
              ),
            );
          case '/home':
            handler.reject(DioException(requestOptions: options, type: type));
          default:
            handler.reject(DioException(requestOptions: options));
        }
      },
    ),
  );
  return dio;
}

Dio _createLocationMissingDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        switch (options.path) {
          case '/users/me':
          case '/feedback/today':
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: options.path == '/users/me'
                    ? _userJson(
                        latitude: null,
                        longitude: null,
                        regionName: null,
                      )
                    : {'exists': false, 'feedback': null},
              ),
            );
          case '/home':
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 400,
                  data: {'detail': 'location is not configured'},
                ),
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

Map<String, dynamic> _userJson({
  double? latitude = 35.6812,
  double? longitude = 139.7671,
  String? regionName = '東京',
}) {
  return {
    'id': '00000000-0000-0000-0000-000000000001',
    'nickname': 'たろう',
    'gender': 'unspecified',
    'cold_sensitivity': 'normal',
    'heat_sensitivity': 'normal',
    'offset_value': 0,
    'departure_time': '09:00:00',
    'return_time': '18:00:00',
    'latitude': latitude,
    'longitude': longitude,
    'region_name': regionName,
    'created_at': '2026-05-06T00:00:00Z',
    'updated_at': '2026-05-06T00:00:00Z',
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

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> clearTokens() async {}

  @override
  Future<void> clearOnboardingCompleted() async {}

  @override
  Future<void> logoutServer({required Dio dio}) async {}

  // No token → simulate an offline anonymous-login failure so the login screen
  // is shown (rather than hitting the network / real secure storage).
  @override
  Future<bool> loginAnonymous({required Dio dio}) async {
    throw const AuthException('offline');
  }
}
