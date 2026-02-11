import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();

  // Factory constructor returns the same instance every time
  factory SessionManager() {
    return _instance;
  }

  // Internal constructor
  SessionManager._internal();

  String _sessionCookie = "";
  // New properties for location
  double _latitude = 0.0;
  double _longitude = 0.0;

  // Getters
  String get sessionCookie => _sessionCookie;
  double get latitude => _latitude;
  double get longitude => _longitude;

  // Setters
  void setSessionCookie(String cookie) {
    _sessionCookie = cookie;
  }

  void setLocation(double lat, double lon) {
    _latitude = lat;
    _longitude = lon;
  }

  // Clear session (e.g., on logout)
  void clearSession() {
    _sessionCookie = "";
    _latitude = 0.0;
    _longitude = 0.0;
  }

  // --- Alert Settings Management ---

  static const String _alertSettingsKey = 'alert_settings';
  static const String _selectedDeviceKey = 'selected_device_id';

  // Save alert configurations (JSON string)
  static Future<void> saveAlertSettings(String settingsJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertSettingsKey, settingsJson);
  }

  // Retrieve alert configurations
  static Future<String?> getAlertSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_alertSettingsKey);
  }

  // Save the currently selected device ID
  static Future<void> saveSelectedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedDeviceKey, deviceId);
  }

  // Retrieve the selected device ID
  static Future<String?> getSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedDeviceKey);
  }
}
