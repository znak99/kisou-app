import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/api_config.dart';
import 'config/theme.dart';
import 'constants/app_strings.dart';
import 'providers/api_provider.dart';
import 'providers/ads_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/travel_plan_provider.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'screens/splash_view.dart';

class KisouApp extends ConsumerStatefulWidget {
  const KisouApp({super.key});

  @override
  ConsumerState<KisouApp> createState() => _KisouAppState();
}

class _KisouAppState extends ConsumerState<KisouApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(adsProvider.notifier).start();
    });
    Future.microtask(() async {
      try {
        await ref
            .read(travelNotificationGatewayProvider)
            .initialize(
              onTap: (planId) {
                ref
                    .read(travelNotificationNavigationProvider.notifier)
                    .queue(planId);
              },
            );
      } catch (_) {
        // Notification initialization is retried by travel-plan
        // reconciliation and must not block app startup.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: KisouTheme.light(),
      darkTheme: KisouTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AuthGate(),
    );
  }
}

/// A short floor prevents a visual flash without delaying ready content.
const _kMinSplash = Duration(milliseconds: 500);
const _kSplashMessageDelay = Duration(milliseconds: 1200);

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  Timer? _minSplashTimer;
  Timer? _messageTimer;
  bool _minSplashElapsed = false;
  bool _messageDelayElapsed = false;
  bool _initialHomeSettled = false;

  @override
  void initState() {
    super.initState();
    _minSplashTimer = Timer(_kMinSplash, () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
    _messageTimer = Timer(_kSplashMessageDelay, () {
      if (mounted) setState(() => _messageDelayElapsed = true);
    });
  }

  @override
  void dispose() {
    _minSplashTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 디자인 확인용 미리보기: 인증/홈으로 넘어가지 않고 스플래시(안내 문구
    // 포함)만 계속 표시한다. 릴리스 빌드에서는 define 이 있어도 무시된다.
    //   ./run dev simulator --dart-define=SPLASH_PREVIEW=true
    const splashPreview = bool.fromEnvironment('SPLASH_PREVIEW');
    if (ApiConfig.developmentFeaturesEnabled && splashPreview) {
      return const SplashView(showMessage: true);
    }

    final authState = ref.watch(authProvider);
    ref.listen(authRequiredProvider, (previous, next) {
      if (next != true) {
        return;
      }
      Future.microtask(() async {
        await ref.read(authProvider.notifier).expireSession();
        ref.read(authRequiredProvider.notifier).clear();
        if (!context.mounted) {
          return;
        }
        // Dismiss any open modal/dialog (e.g. the feedback sheet) so it doesn't
        // float over the login screen after the session ends (audit B11).
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.sessionExpired)),
        );
      });
    });

    // Do not delay ready content beyond a brief anti-flash floor. A neutral
    // status appears only when startup genuinely takes longer than 1.2s.
    if (!_minSplashElapsed || authState.isLoading) {
      return SplashView(
        showMessage: _messageDelayElapsed && authState.isLoading,
      );
    }

    return authState.when(
      data: (state) {
        if (!state.isAuthenticated) {
          return const LoginScreen();
        }
        if (state.isNewUser) {
          return const OnboardingScreen();
        }
        // A returning user's token is local. Keep visual continuity only until
        // home settles or the 1.2s message threshold is reached. Errors leave
        // the splash immediately and render the actionable home recovery UI.
        if (!_initialHomeSettled) {
          final homeState = ref.watch(homeProvider);
          if (homeState.isLoading && !_messageDelayElapsed) {
            return const SplashView();
          }
          _initialHomeSettled = true;
        }
        return const RootShell();
      },
      error: (_, _) => const LoginScreen(),
      loading: () => const SplashView(),
    );
  }
}
