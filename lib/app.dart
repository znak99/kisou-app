import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'constants/app_strings.dart';
import 'providers/api_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/api_error.dart';
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
      home: const _AuthGate(),
    );
  }
}

/// Minimum time the splash stays up, so it never flashes by on a fast start.
const _kMinSplash = Duration(milliseconds: 1500);

/// While the server is unreachable at startup we hold the splash and keep
/// retrying, so a server that comes back up lets the user straight in. Bounded
/// so a real outage can't strand them: after this we fall through to the home
/// error screen, which has its own retry.
const _kHomeRetryDelay = Duration(seconds: 2);
const _kHomeRetryLimit = 5;

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  Timer? _minSplashTimer;
  bool _minSplashElapsed = false;
  bool _initialHomeSettled = false;
  Timer? _homeRetryTimer;
  int _homeRetries = 0;

  @override
  void initState() {
    super.initState();
    _minSplashTimer = Timer(_kMinSplash, () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
  }

  @override
  void dispose() {
    _minSplashTimer?.cancel();
    _homeRetryTimer?.cancel();
    super.dispose();
  }

  /// Only wait on the splash for failures a retry could actually fix. A missing
  /// location or an expired session never resolves itself, so those go straight
  /// through to the screens that can handle them.
  bool _shouldWaitForServer(Object error) {
    if (_homeRetries >= _kHomeRetryLimit) {
      return false;
    }
    return switch (classifyApiError(error)) {
      ApiErrorKind.offline || ApiErrorKind.timeout => true,
      _ => false,
    };
  }

  void _scheduleHomeRetry() {
    if (_homeRetryTimer?.isActive ?? false) {
      return;
    }
    _homeRetryTimer = Timer(_kHomeRetryDelay, () {
      if (!mounted) return;
      _homeRetries++;
      ref.read(homeProvider.notifier).retry();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 디자인 확인용 미리보기: 인증/홈으로 넘어가지 않고 스플래시(안내 문구
    // 포함)만 계속 표시한다. 릴리스 빌드에서는 define 이 있어도 무시된다.
    //   ./run dev simulator --dart-define=SPLASH_PREVIEW=true
    const splashPreview = bool.fromEnvironment('SPLASH_PREVIEW');
    if (!kReleaseMode && splashPreview) {
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

    // Splash stays up until BOTH the minimum time has passed and auth settled.
    // Once the minimum has elapsed and we're still waiting on the server, the
    // splash explains itself instead of sitting there silently.
    if (!_minSplashElapsed || authState.isLoading) {
      return SplashView(showMessage: _minSplashElapsed && authState.isLoading);
    }

    return authState.when(
      data: (state) {
        if (!state.isAuthenticated) {
          return const LoginScreen();
        }
        if (state.isNewUser) {
          return const OnboardingScreen();
        }
        // Returning user: a stored token authenticates without touching the
        // server, so the splash would otherwise end before we've fetched
        // anything. Keep it up for the FIRST home load too, then hand over.
        // Only the first one — once settled we stop gating, otherwise a retry
        // from the home error screen would throw the user back to the splash.
        if (!_initialHomeSettled) {
          final homeState = ref.watch(homeProvider);
          if (homeState.isLoading) {
            return const SplashView(showMessage: true);
          }
          if (homeState.hasError && _shouldWaitForServer(homeState.error!)) {
            // Server unreachable: hold the splash and keep trying so a server
            // that comes back lets the user straight in.
            _scheduleHomeRetry();
            return const SplashView(showMessage: true);
          }
          // Ready, or an error only the user can resolve (location missing,
          // session expired). Hand over; home renders its own error state.
          _initialHomeSettled = true;
        }
        return const RootShell();
      },
      error: (_, _) => const LoginScreen(),
      loading: () => const SplashView(),
    );
  }
}
