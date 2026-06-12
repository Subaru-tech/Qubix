import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeState {
  final ThemeMode themeMode;
  final String name;

  const ThemeState({
    required this.themeMode,
    required this.name,
  });
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    return const ThemeState(
      themeMode: ThemeMode.dark,
      name: 'Dark Dev',
    );
  }

  void setTheme(String name) {
    ThemeMode mode;
    if (name == 'Light Minimal') {
      mode = ThemeMode.light;
    } else {
      mode = ThemeMode.dark;
    }
    state = ThemeState(themeMode: mode, name: name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
