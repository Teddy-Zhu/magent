import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const _sessionOpenAtBottomKey = 'settings_session_open_at_bottom';

  Future<bool> getSessionOpenAtBottom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionOpenAtBottomKey) ?? true;
  }

  Future<void> setSessionOpenAtBottom(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionOpenAtBottomKey, value);
  }
}
