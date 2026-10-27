import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SharedPrefsService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUser = 'cached_user';
  static const String _keyThemeMode = 'theme_mode';

  // Lưu trạng thái đăng nhập
  static Future<void> saveLoginSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  // Lấy trạng thái đăng nhập
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Lấy thông tin user đã lưu
  static Future<AppUser?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(userJson);
        return AppUser.fromJson(map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Đăng xuất
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUser);
  }

  // Lưu Dark / Light Mode
  static Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThemeMode, isDark);
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyThemeMode) ?? false;
  }
}
