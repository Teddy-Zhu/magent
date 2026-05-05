import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/services/app_settings_service.dart';

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

final showAiCommitSessionsControllerProvider =
    AsyncNotifierProvider<ShowAiCommitSessionsController, bool>(
      ShowAiCommitSessionsController.new,
    );

final viewerFontScaleControllerProvider =
    AsyncNotifierProvider<ViewerFontScaleController, double>(
      ViewerFontScaleController.new,
    );

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final setting = await ref.read(appSettingsServiceProvider).getThemeMode();
    return setting.toThemeMode();
  }

  Future<void> setMode(AppThemeModeSetting setting) async {
    await ref.read(appSettingsServiceProvider).setThemeMode(setting);
    state = AsyncData(setting.toThemeMode());
  }
}

class ShowAiCommitSessionsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(appSettingsServiceProvider).getShowAiCommitSessions();
  }

  Future<void> setVisible(bool value) async {
    await ref.read(appSettingsServiceProvider).setShowAiCommitSessions(value);
    state = AsyncData(value);
  }
}

class ViewerFontScaleController extends AsyncNotifier<double> {
  @override
  Future<double> build() {
    return ref.read(appSettingsServiceProvider).getViewerFontScale();
  }

  Future<void> setScale(double value) async {
    await ref.read(appSettingsServiceProvider).setViewerFontScale(value);
    final current = await ref.read(appSettingsServiceProvider).getViewerFontScale();
    state = AsyncData(current);
  }
}

extension AppThemeModeSettingX on AppThemeModeSetting {
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeModeSetting.light:
        return ThemeMode.light;
      case AppThemeModeSetting.dark:
        return ThemeMode.dark;
      case AppThemeModeSetting.system:
        return ThemeMode.system;
    }
  }
}
