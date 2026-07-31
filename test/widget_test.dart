import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kisou_app/app.dart';
import 'package:kisou_app/config/app_links.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/providers/account_deletion_credential_provider.dart';
import 'package:kisou_app/providers/api_provider.dart';
import 'package:kisou_app/providers/auth_provider.dart';
import 'package:kisou_app/providers/external_link_provider.dart';
import 'package:kisou_app/providers/travel_plan_provider.dart';
import 'package:kisou_app/providers/user_provider.dart';
import 'package:kisou_app/repositories/travel_plan_repository.dart';
import 'package:kisou_app/screens/analysis/analysis_screen.dart';
import 'package:kisou_app/screens/onboarding/onboarding_screen.dart';
import 'package:kisou_app/services/auth_service.dart';
import 'package:kisou_app/services/account_deletion_credential_store.dart';
import 'package:kisou_app/services/travel_notification_service.dart';
import 'package:kisou_app/services/user_service.dart';
import 'package:kisou_app/utils/jp_date.dart';
import 'package:kisou_app/widgets/feeling_headline.dart';

void main() {
  setUp(() {
    // 날짜 예상 화면의 일일 횟수(quota)가 SharedPreferences 를 읽는다.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows login screen for signed out users', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(hasTokenValue: false),
          ),
          accountDeletionCredentialStoreProvider.overrideWithValue(
            _NoopDeletionCredentialStore(),
          ),
          travelPlanRepositoryProvider.overrideWithValue(
            MemoryTravelPlanRepository(),
          ),
          travelNotificationGatewayProvider.overrideWithValue(
            MemoryTravelNotificationGateway(),
          ),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.startupFailedTitle), findsOneWidget);
    // Anonymous-only MVP: social sign-in is hidden; a retry button is offered.
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.developerOptions), findsOneWidget);
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

      expect(find.text('1/4'), findsOneWidget);
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
    expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
    expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
    expect(
      find.text(AppStrings.environmentMinistryWbgtDataAttribution),
      findsOneWidget,
    );
    expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
    // The feedback action lives in the shared top toolbar.
    expect(find.text(AppStrings.feedbackButton), findsOneWidget);

    await tester.tap(find.text(AppStrings.feedbackButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.feedbackWhenTitle), findsOneWidget);
  });

  testWidgets('home feeling card opens the personal analysis screen', (
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
    await tester.scrollUntilVisible(
      find.text(AppStrings.feelingLead),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.feelingLead));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.analysisTitle), findsOneWidget);
    expect(find.text(AppStrings.analysisAverageNotice), findsOneWidget);
  });

  testWidgets('menu comfort analysis opens the analysis screen and returns', (
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

    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text(AppStrings.analysisTitle)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileCategoryComfort), findsOneWidget);
    expect(find.text(AppStrings.analysisEntryDescription), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(AppStrings.analysisTitle));
    await tester.pumpAndSettle();

    expect(find.byType(AnalysisScreen), findsOneWidget);
    expect(find.text(AppStrings.analysisAverageNotice), findsOneWidget);

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AnalysisScreen), findsNothing);
    expect(find.text(AppStrings.analysisEntryDescription), findsOneWidget);
    expect(
      find.bySemanticsLabel(AppStrings.selectedTab(AppStrings.tabProfile)),
      findsOneWidget,
    );
  });

  testWidgets('予報 탭: 내일 카드·피드백 유도·날짜 예상 입구가 보인다', (WidgetTester tester) async {
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

    // 하단 탭에 分析 대신 予報가 있다.
    expect(find.text(AppStrings.tabForecast), findsOneWidget);
    await tester.tap(find.text(AppStrings.tabForecast));
    await tester.pumpAndSettle();

    // 내일(19°) vs 오늘(22°) 목 데이터 → 3° 시원해진다는 문구.
    expect(find.text('明日は今日より3°涼しくなります'), findsOneWidget);
    expect(find.text(AppStrings.forecastTomorrowSection), findsOneWidget);
    expect(find.text(AppStrings.forecastUpcomingSection), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
    expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
    expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
    // 오늘 피드백 미기록 → 유도 카드.
    expect(find.text(AppStrings.forecastNudgeTitle), findsOneWidget);
    expect(find.text(AppStrings.forecastNudgeAction), findsOneWidget);
    // 날짜 예상 입구는 툴바의 pill 버튼.
    expect(find.text(AppStrings.forecastOutlookEntry), findsOneWidget);
  });

  testWidgets('予報 탭: 기록 완료 카드 전체에서 수정 시트를 연다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              hasTokenValue: true,
              onboardingCompletedValue: true,
            ),
          ),
          apiClientProvider.overrideWithValue(_createRecordedAppDio()),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);

    await tester.tap(find.text(AppStrings.tabForecast));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.forecastNudgeDone), findsOneWidget);
    expect(find.text(AppStrings.forecastNudgeEdit), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.text(AppStrings.forecastNudgeDone));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.feedbackEditingSaved), findsOneWidget);
  });

  testWidgets('予報 탭: 기후 극값은 숨기고 평균 범위와 근거만 표시한다', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
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

    await tester.tap(find.text(AppStrings.tabForecast));
    await tester.pumpAndSettle();

    // 툴바의 입구를 눌러 전용 페이지로 이동.
    await tester.tap(find.text(AppStrings.forecastOutlookEntry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.forecastOutlookTitle), findsOneWidget);

    // 날짜를 고르기 전에는 予想する 비활성.
    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);

    // 날짜 피커를 열고 초기값(내일)을 그대로 확정.
    await tester.tap(find.text(AppStrings.forecastOutlookDateLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.forecastOutlookSubmit));
    await tester.pumpAndSettle();

    // climatology 목 응답: 평균이 메인 숫자(15°〜24°), 근거 템플릿(과거
    // 5년·표본 35일), 개인 체감 문구, 기본 도시(東京)가 결과에 붙는다.
    expect(
      find.text(AppStrings.forecastClimateRange('15', '24')),
      findsOneWidget,
    );
    expect(
      find.text(
        AppStrings.forecastExplainClimatology(
          years: 5,
          sampleDays: 35,
          low: '15',
          high: '24',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.forecastFeelingLine('COOL')), findsOneWidget);
    expect(find.textContaining('東京・'), findsOneWidget);
    expect(find.text(AppStrings.openMeteoDataAttribution), findsOneWidget);
    expect(find.text(AppStrings.openMeteoLicense), findsOneWidget);
    expect(find.text(AppStrings.weatherDataModified), findsOneWidget);
    for (final extreme in ['-91', '67', '-83', '79']) {
      expect(find.textContaining(extreme), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(extreme))),
        findsNothing,
      );
    }
    semantics.dispose();
  });

  testWidgets('shows complete settings list from home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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
    expect(find.text(AppStrings.profileCategoryPersonal), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, isNotNull);
    expect(progress.value!, closeTo(0.1, 0.001));

    // The account actions sit at the bottom of the (lazy) list.
    await tester.scrollUntilVisible(
      find.text(AppStrings.privacyPolicy),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    // 게스트 계정은 세션 복구형 로그아웃을 노출하지 않지만 외부 삭제용
    // 자격정보에는 접근할 수 있다.
    expect(find.text(AppStrings.logout), findsNothing);
    expect(find.text(AppStrings.accountDeletionCredentials), findsOneWidget);
    expect(find.text(AppStrings.accountDelete), findsOneWidget);
    expect(find.text(AppStrings.profileCategorySupport), findsOneWidget);
    expect(find.text(AppStrings.aboutKisou), findsOneWidget);
    expect(find.text(AppStrings.privacyPolicy), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final completedProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(completedProgress.value!, closeTo(1, 0.001));
  });

  testWidgets('opens the published privacy policy in an external browser', (
    WidgetTester tester,
  ) async {
    Uri? launchedUri;
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
          externalUrlLauncherProvider.overrideWithValue((uri) async {
            launchedUri = uri;
            return true;
          }),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.privacyPolicy),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.text(AppStrings.privacyPolicy));
    await tester.pump();

    expect(
      AppLinks.privacyPolicy.toString(),
      'https://kisou-pages.znak-llm.chatgpt.site/privacy/',
    );
    expect(launchedUri, AppLinks.privacyPolicy);
    expect(launchedUri!.scheme, 'https');
    expect(launchedUri!.host, 'kisou-pages.znak-llm.chatgpt.site');
    expect(launchedUri!.path, '/privacy/');
    expect(find.text(AppStrings.privacyPolicyOpenFailed), findsNothing);
  });

  testWidgets('shows an error when the privacy policy cannot be opened', (
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
          externalUrlLauncherProvider.overrideWithValue((_) async => false),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.privacyPolicy),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.text(AppStrings.privacyPolicy));
    await tester.pump();

    expect(find.text(AppStrings.privacyPolicyOpenFailed), findsOneWidget);
  });

  testWidgets('shows an error when opening the privacy policy throws', (
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
          externalUrlLauncherProvider.overrideWithValue(
            (_) => Future<bool>.error(StateError('launcher failed')),
          ),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.privacyPolicy),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.text(AppStrings.privacyPolicy));
    await tester.pump();

    expect(find.text(AppStrings.privacyPolicyOpenFailed), findsOneWidget);
  });

  testWidgets('ignores repeated privacy policy taps while opening', (
    WidgetTester tester,
  ) async {
    final launchResult = Completer<bool>();
    var launchCount = 0;
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
          externalUrlLauncherProvider.overrideWithValue((_) {
            launchCount += 1;
            return launchResult.future;
          }),
        ],
        child: const KisouApp(),
      ),
    );
    await pumpPastSplash(tester);
    await tester.tap(find.text(AppStrings.tabProfile));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(AppStrings.privacyPolicy),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.text(AppStrings.privacyPolicy));
    await tester.tap(find.text(AppStrings.privacyPolicy));
    await tester.pump();

    expect(launchCount, 1);
    launchResult.complete(true);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.privacyPolicyOpenFailed), findsNothing);
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
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // 시작 화면에 붙잡아 두지 않고 원인을 밝힌 복구 UI로 전환한다.
    expect(find.text(AppStrings.splashLoading), findsNothing);
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
        accountDeletionCredentialStoreProvider.overrideWithValue(
          _NoopDeletionCredentialStore(),
        ),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
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

    expect(find.text(AppStrings.startupFailedTitle), findsOneWidget);
    expect(find.text(AppStrings.sessionExpired), findsOneWidget);
  });

  testWidgets('local deletion cleanup failure shows persistent recovery', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      hasTokenValue: true,
      onboardingCompletedValue: true,
      failLocalCleanup: true,
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiClientProvider.overrideWithValue(_createAppDio()),
        accountDeletionCredentialStoreProvider.overrideWithValue(
          _NoopDeletionCredentialStore(),
        ),
        travelPlanRepositoryProvider.overrideWithValue(
          MemoryTravelPlanRepository(),
        ),
        travelNotificationGatewayProvider.overrideWithValue(
          MemoryTravelNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KisouApp()),
    );
    await pumpPastSplash(tester);

    await expectLater(
      container.read(authProvider.notifier).completeAccountDeletion(),
      throwsA(isA<LocalAccountCleanupException>()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.accountDeleteLocalCleanupTitle),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.accountDeleteLocalCleanupFailed),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.accountDeleteLocalCleanupRetry),
      findsOneWidget,
    );
  });

  testWidgets('onboarding exposes account deletion before completion', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      hasTokenValue: true,
      onboardingCompletedValue: false,
    );
    final userService = _DeleteTrackingUserService();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        userServiceProvider.overrideWithValue(userService),
        accountDeletionCredentialStoreProvider.overrideWithValue(
          _NoopDeletionCredentialStore(),
        ),
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
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.onboardingAccountDelete));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.accountDeleteTitle), findsOneWidget);
    expect(
      find.text(AppStrings.onboardingAccountDeleteConfirm),
      findsOneWidget,
    );
    await tester.tap(find.text(AppStrings.deleteAction));
    await tester.pumpAndSettle();
    expect(userService.deleteCallCount, 1);
    expect(authService.didClearLocalAccountData, isTrue);
  });

  testWidgets('onboarding nickname step blocks empty input and advances', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await tester.pump();

    expect(find.text('1/4'), findsOneWidget);
    expect(find.text(AppStrings.nicknamePrompt), findsOneWidget);

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.next),
    );
    expect(nextButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'たろう');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.next));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text(AppStrings.genderPrompt), findsOneWidget);
  });

  testWidgets('onboarding nickname keyboard closes on done and outside tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await tester.pump();

    final textField = find.byType(TextField);
    await tester.tap(textField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(textField);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text(AppStrings.nicknamePrompt));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('feeling card keeps original gradient and black foreground', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FeelingHeadline(feeling: 'PERFECT')),
      ),
    );

    final lead = tester.widget<Text>(find.text(AppStrings.feelingLead));
    final phrase = tester.widget<Text>(find.text(AppStrings.feelingPerfect));
    final icon = tester.widget<Icon>(
      find.byIcon(Icons.sentiment_satisfied_rounded),
    );
    expect(lead.style?.color, KisouTheme.feelingForeground);
    expect(phrase.style?.color, KisouTheme.feelingForeground);
    expect(icon.color, KisouTheme.feelingForeground);

    final card = tester.widget<Ink>(
      find.descendant(
        of: find.byType(FeelingHeadline),
        matching: find.byType(Ink),
      ),
    );
    final decoration = card.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final feelingColor = KisouTheme.feelingColor('PERFECT');
    expect(gradient.colors, [
      Color.lerp(feelingColor, Colors.white, 0.12),
      feelingColor,
    ]);
  });

  testWidgets('home card expansion is immediate when motion is reduced', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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

    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
      Duration.zero,
    );
  });

  testWidgets('재방문 사용자: 홈 응답이 늦어도 1.2초 뒤 앱 화면으로 전환한다', (
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
          apiClientProvider.overrideWithValue(_createSlowDio()),
        ],
        child: const KisouApp(),
      ),
    );
    await tester.pump();

    // 최소 시간 전: 스플래시만, 문구 없음
    expect(find.text(AppStrings.splashLoading), findsNothing);

    // 장기 로딩은 스플래시에 사용자를 붙잡지 않고 홈 로딩 상태로 넘긴다.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text(AppStrings.splashLoading), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  });

  testWidgets('서버가 죽어 있으면 즉시 복구 화면을 표시하고 재시도할 수 있다', (
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
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.offlineError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsWidgets);

    // 서버가 살아난 뒤 사용자가 재시도하면 홈으로 진입한다.
    serverDown = false;
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.retry).first);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.splashLoading), findsNothing);
    expect(find.text('たろうさん、${AppStrings.todayClothing}'), findsOneWidget);
  });
}

/// KisouApp 은 시작 시 최대 0.5초의 짧은 anti-flash 스플래시를 둔다.
/// 실제 화면을 검증하려면 그 시간을 넘겨야 한다.
Future<void> pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// 응답을 2초 늦춰 1.2초 스플래시 상한 이후의 로딩 전환을 검증한다.
Dio _createSlowDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        _resolveAppRequest(options, handler);
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

Dio _createRecordedAppDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/feedback/today') {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'exists': true,
                'feedback': {
                  'id': 'saved-feedback',
                  'date': formatIsoDate(jstToday()),
                  'feedback_value': 'perfect',
                  'actual_top': 'SHORT_SLEEVE',
                  'actual_bottom': 'LONG_PANTS',
                  'actual_outer': null,
                  'time_slots': ['MORNING'],
                  'created_at': '2026-07-29T00:00:00Z',
                  'updated_at': '2026-07-29T00:00:00Z',
                },
              },
            ),
          );
          return;
        }
        _resolveAppRequest(options, handler);
      },
    ),
  );
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
              'today': _weather(tempHigh: 22, tempLow: 14, wbgtMax: 24),
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
    case '/analysis':
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: {
            'offset_value': 0,
            'tendency': 'neutral',
            'total_feedbacks': 4,
            'feedback_counts': {'cold': 1, 'perfect': 2, 'hot': 1},
            'history': [
              for (var day = 1; day <= 4; day++)
                {
                  'date': '2026-05-0$day',
                  'feedback_value': day == 1 ? 'cold' : 'perfect',
                  'temp_high': 22,
                  'temp_low': 14,
                  'humidity': 55,
                  'offset_at_time': 0,
                },
            ],
          },
        ),
      );
    case '/forecast/tomorrow':
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: {
            'date': '2026-05-07',
            'feeling': 'PERFECT',
            'comfort_min': 20,
            'comfort_max': 24,
            'recommendations': [
              {
                'rank': 1,
                'top': 'LONG_SLEEVE',
                'bottom': 'LONG_PANTS',
                'outer': null,
              },
            ],
            // 내일 19° vs 오늘 22° → '明日は今日より3°涼しくなります'
            'weather': _weather(tempHigh: 19, tempLow: 12),
            'today_weather': _weather(tempHigh: 22, tempLow: 14),
          },
        ),
      );
    case '/forecast/outlook/quota':
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: _outlookQuota(remaining: 3),
        ),
      );
    case '/forecast/outlook':
      final requestData = options.data as Map<String, dynamic>;
      handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: {
            'date': requestData['date'],
            'mode': 'climatology',
            'feeling': 'COOL',
            'comfort_min': 12,
            'comfort_max': 18,
            'recommendations': [
              {
                'rank': 1,
                'top': 'THIN_LONG',
                'bottom': 'LONG_PANTS',
                'outer': 'LIGHT_OUTER',
              },
            ],
            'weather': null,
            'climate': {
              'temp_low_avg': 15.2,
              'temp_low_min': -91.0,
              'temp_low_max': 67.0,
              'temp_high_avg': 24.2,
              'temp_high_min': -83.0,
              'temp_high_max': 79.0,
              'years_used': 5,
              'sample_days': 35,
            },
            'quota_consumed': 'free',
            'quota': _outlookQuota(remaining: 2),
          },
        ),
      );
    default:
      handler.reject(DioException(requestOptions: options));
  }
}

Map<String, dynamic> _outlookQuota({required int remaining}) {
  return {
    'date': '2026-07-31',
    'free_limit': 3,
    'free_used': 3 - remaining,
    'free_remaining': remaining,
    'reward_credits': 0,
    'total_remaining': remaining,
    'resets_at': '2026-07-31T15:00:00Z',
    'ads_available': remaining == 0,
  };
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
  double? wbgtMax,
}) {
  return {
    'temp_high': tempHigh,
    'temp_low': tempLow,
    'feels_like_high': tempHigh,
    'feels_like_low': tempLow,
    'humidity_avg': 55,
    'wind_speed_avg': 2.0,
    'precipitation_chance_max': null,
    'wbgt_max': wbgtMax,
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
    this.failLocalCleanup = false,
  });

  final bool hasTokenValue;
  final bool onboardingCompletedValue;
  final bool failLocalCleanup;
  bool didClearLocalAccountData = false;
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
  Future<void> clearLocalAccountData() async {
    if (failLocalCleanup) {
      throw StateError('local cleanup failed');
    }
    didClearLocalAccountData = true;
  }

  @override
  Future<void> logoutServer({required Dio dio}) async {}

  // No token → simulate an offline anonymous-login failure so the login screen
  // is shown (rather than hitting the network / real secure storage).
  @override
  Future<bool> loginAnonymous({required Dio dio}) async {
    throw const AuthException('offline');
  }
}

class _DeleteTrackingUserService extends UserService {
  _DeleteTrackingUserService() : super(Dio());

  var deleteCallCount = 0;

  @override
  Future<void> deleteMe() async {
    deleteCallCount++;
  }
}

class _NoopDeletionCredentialStore extends AccountDeletionCredentialStore {
  @override
  Future<void> delete() async {}
}
