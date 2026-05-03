import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'providers/api_provider.dart';

const _appTitle = 'キソウ';

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
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: KisouTheme.light(),
      home: const _TemporaryHomeScreen(),
    );
  }
}

class _TemporaryHomeScreen extends StatelessWidget {
  const _TemporaryHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(_appTitle, style: Theme.of(context).textTheme.displaySmall),
      ),
    );
  }
}
