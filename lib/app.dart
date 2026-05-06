import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'constants/app_strings.dart';
import 'providers/api_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

class KisouApp extends ConsumerStatefulWidget {
  const KisouApp({super.key});

  @override
  ConsumerState<KisouApp> createState() => _KisouAppState();
}

class _KisouAppState extends ConsumerState<KisouApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(apiHealthCheckEnabledProvider)) {
        _checkApiHealth();
      }
    });
  }

  Future<void> _checkApiHealth() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Object?>('/health');
      debugPrint('API connected: ${response.data}');
    } catch (error) {
      debugPrint('API connection failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (state) {
        if (!state.isAuthenticated) {
          return const LoginScreen();
        }
        if (state.isNewUser) {
          return const OnboardingScreen();
        }
        return const HomeScreen();
      },
      error: (_, _) => const LoginScreen(),
      loading: () => const _LoadingScreen(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
