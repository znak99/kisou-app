import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme mode: defaults to following the system, but the user can toggle
/// light/dark from the profile. The choice is persisted across launches.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

const _themeModeKey = 'theme_mode';

/// Reads the persisted theme synchronously from already-loaded preferences.
/// Used by `main()` to seed the provider before the first frame so a saved
/// light/dark choice doesn't flash the system theme first (audit B22).
ThemeMode themeModeFromPreferences(SharedPreferences prefs) {
  return switch (prefs.getString(_themeModeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController([this._initialMode = ThemeMode.system]);

  final ThemeMode _initialMode;

  @override
  ThemeMode build() {
    // When not seeded from main() (e.g. tests), fall back to an async load.
    if (_initialMode == ThemeMode.system) {
      _load();
    }
    return _initialMode;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) {
      return;
    }
    final mode = themeModeFromPreferences(prefs);
    if (mode != state) {
      state = mode;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// The persisted preference has already been removed with account data.
  /// Reset only in-memory state so deletion does not recreate the key.
  void resetAfterAccountDeletion() {
    state = ThemeMode.system;
  }
}
