import 'package:flutter/services.dart';

/// Swaps the iOS app icon to match the in-app theme (not the system appearance).
///
/// iOS only: uses alternate app icons via a platform channel. On Android — and
/// on iOS versions/simulators that don't support alternate icons — this is a
/// no-op. Note: iOS shows a one-time system alert when the icon changes, and
/// alternate icons only take visible effect on a physical device.
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
      // Alternate icons unsupported / not configured — ignore.
    } on MissingPluginException catch (_) {
      // Non-iOS platform — ignore.
    }
  }
}
