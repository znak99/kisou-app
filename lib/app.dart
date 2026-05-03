import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/theme.dart';

const _appTitle = 'キソウ';

class KisouApp extends StatelessWidget {
  const KisouApp({super.key});

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
