import 'package:flutter/services.dart';

/// Swaps the iOS app icon to match the in-app theme (not the system appearance).
///
/// iOS only, and a physical-device feature: `UIApplication.supportsAlternateIcons`
/// returns false on the iOS Simulator, so the icon does not change there. On a
/// real device the icon switches (light ⇄ dark) with the in-app theme. Android
/// cannot change the launcher icon at runtime, so it stays static.
class AppIconService {
  const AppIconService._();

  static const _channel = MethodChannel('kisou/app_icon');
  static const _darkIcon = 'AppIconDark';

  static String? _applied = _uninitialized;
  static const _uninitialized = '__init__';

  /// null → primary (light) icon; 'AppIconDark' → dark alternate icon.
  static Future<void> applyForBrightness(Brightness brightness) async {
    final name = brightness == Brightness.dark ? _darkIcon : null;
    if (name == _applied) {
      return;
    }
    _applied = name;
    try {
      await _channel.invokeMethod<void>('setIcon', {'name': name});
    } on PlatformException catch (_) {
      // Alternate icons unsupported (e.g. iOS Simulator) — ignore.
    } on MissingPluginException catch (_) {
      // Non-iOS platform — ignore.
    }
  }
}
