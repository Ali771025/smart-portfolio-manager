import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return SharedPreferences.getInstance();
}

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  static const _themeModeStorageKey = 'app_theme_mode';
  bool _isDisposed = false;

  @override
  ThemeMode build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    _restoreSavedThemeMode();
    return ThemeMode.system;
  }

  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_themeModeStorageKey, mode.name);
  }

  Future<void> _restoreSavedThemeMode() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final storedValue = prefs.getString(_themeModeStorageKey);
    if (storedValue == null || _isDisposed) {
      return;
    }

    final parsedMode = _parseStoredThemeMode(storedValue);
    if (parsedMode != null) {
      state = parsedMode;
    }
  }

  ThemeMode? _parseStoredThemeMode(String rawValue) {
    return switch (rawValue) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }
}
