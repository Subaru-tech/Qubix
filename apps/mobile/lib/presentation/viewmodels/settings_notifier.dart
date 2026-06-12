import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/theme/theme_notifier.dart';

class SettingsState {
  final User? user;
  final ThemeMode themeMode;
  final bool isLoading;

  const SettingsState({
    this.user,
    required this.themeMode,
    this.isLoading = false,
  });

  SettingsState copyWith({
    User? user,
    ThemeMode? themeMode,
    bool? isLoading,
  }) {
    return SettingsState(
      user: user ?? this.user,
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final themeState = ref.watch(themeProvider);
    final authRepo = ref.read(authRepositoryProvider);
    
    User? user;
    try {
      user = await authRepo.getMe();
    } catch (e) {
      // Ignore if user cannot be loaded right away
    }

    return SettingsState(
      user: user,
      themeMode: themeState.themeMode,
    );
  }

  Future<void> loadUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      final current = state.value;
      state = AsyncValue.data(SettingsState(
        user: user,
        themeMode: current?.themeMode ?? ref.read(themeProvider).themeMode,
        isLoading: false,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isLoading: true));
    }
    
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isLoading: false));
      }
    }
  }

  Future<void> deleteAccount() async {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isLoading: true));
    }
    
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
    } finally {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isLoading: false));
      }
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
