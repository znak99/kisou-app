import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/ad_config.dart';
import 'config/api_config.dart';
import 'config/push_config.dart';
import 'providers/theme_provider.dart';
import 'services/push_messaging_gateway.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validateRuntime();
  AdConfig.validateRuntime();
  PushConfig.validateRuntime();
  await PushMessagingBootstrap.initializeForRuntime();
  // Portrait-only across platforms (matches the design; avoids landscape
  // overflow) — audit B18.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Preload the saved theme so the very first frame renders in it instead of
  // flashing the system theme and then correcting (audit B22).
  final prefs = await SharedPreferences.getInstance();
  final initialThemeMode = themeModeFromPreferences(prefs);
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          () => ThemeModeController(initialThemeMode),
        ),
      ],
      child: const KisouApp(),
    ),
  );
}
