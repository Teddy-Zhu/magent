import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeModeSetting {
  system('system'),
  light('light'),
  dark('dark');

  final String value;

  const AppThemeModeSetting(this.value);

  static AppThemeModeSetting fromValue(String? value) {
    for (final mode in values) {
      if (mode.value == value) return mode;
    }
    return AppThemeModeSetting.system;
  }
}

class AppSettingsService {
  static const _sessionOpenAtBottomKey = 'settings_session_open_at_bottom';
  static const _showAiCommitSessionsKey = 'settings_show_ai_commit_sessions';
  static const _themeModeKey = 'settings_theme_mode';
  static const _viewerFontScaleKey = 'settings_viewer_font_scale';

  /// 文件查看器（代码/文本/Markdown 源码/Diff）的字号缩放范围。
  static const double viewerFontScaleMin = 0.85;
  static const double viewerFontScaleMax = 1.6;
  static const double viewerFontScaleDefault = 1.0;

  Future<bool> getSessionOpenAtBottom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionOpenAtBottomKey) ?? true;
  }

  Future<void> setSessionOpenAtBottom(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionOpenAtBottomKey, value);
  }

  Future<bool> getShowAiCommitSessions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showAiCommitSessionsKey) ?? false;
  }

  Future<void> setShowAiCommitSessions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAiCommitSessionsKey, value);
  }

  Future<AppThemeModeSetting> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return AppThemeModeSetting.fromValue(prefs.getString(_themeModeKey));
  }

  Future<void> setThemeMode(AppThemeModeSetting value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.value);
  }

  Future<double> getViewerFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_viewerFontScaleKey);
    if (raw == null) return viewerFontScaleDefault;
    return raw.clamp(viewerFontScaleMin, viewerFontScaleMax);
  }

  Future<void> setViewerFontScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = value.clamp(viewerFontScaleMin, viewerFontScaleMax);
    await prefs.setDouble(_viewerFontScaleKey, clamped);
  }
}
