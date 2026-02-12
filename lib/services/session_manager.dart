import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String keyCookie = 'session_cookie';
  static const String keyDeviceId = 'selected_device_id';
  static const String keyAlertSettings = 'alert_settings';

  // Save the complete session cookie
  static Future<void> saveSession(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCookie, cookie);
  }

  static Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCookie);
  }

  // Save the currently selected device ID for background monitoring
  static Future<void> saveSelectedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDeviceId, deviceId);
  }

  static Future<String?> getSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDeviceId);
  }

  // Save alert thresholds (stored as JSON string)
  static Future<void> saveAlertSettings(String settingsJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAlertSettings, settingsJson);
  }

  static Future<String?> getAlertSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAlertSettings);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCookie);
    await prefs.remove(keyDeviceId);
  }
}
