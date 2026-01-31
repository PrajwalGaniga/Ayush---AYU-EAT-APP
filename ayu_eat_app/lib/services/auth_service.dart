import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyPhone = "user_phone";
  static const String _keyIsLoggedIn = "is_logged_in";

  // Save session after Login or Register
  static Future<void> saveSession(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // Check if user is already logged in (used in main.dart)
  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  // Clear data on Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}