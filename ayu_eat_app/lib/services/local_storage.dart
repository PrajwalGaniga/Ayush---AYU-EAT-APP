import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  // Save any Map (JSON) with a specific key
  static Future<void> save(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  // Load the saved Map
  static Future<Map<String, dynamic>?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}