import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// 1. The callback function must be top-level or static
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize services inside the isolate
    final prefs = await SharedPreferences.getInstance();
    final String? cookie = prefs.getString('session_cookie');
    final String? deviceId = prefs.getString('selected_device_id');
    final String? settingsJson = prefs.getString('alert_settings');

    if (cookie == null || deviceId == null || settingsJson == null) {
      return Future.value(false);
    }

    // Parse Settings
    Map<String, dynamic> settings = jsonDecode(settingsJson);

    try {
      // Fetch Live Data
      final response = await http.get(
        Uri.parse('https://gridsphere.in/station/api/live-data/$deviceId'),
        headers: {
          'Cookie': cookie,
          'User-Agent': 'FlutterApp',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reading = (data is List) ? data[0] : data['data'][0];

        // Check Thresholds
        await NotificationService.initialize();

        _checkThreshold(reading, settings, 'temp', 'Air Temperature', '°C', 1);
        _checkThreshold(reading, settings, 'humidity', 'Humidity', '%', 2);
        _checkThreshold(
            reading, settings, 'surface_humidity', 'Soil Moisture', '%', 3);

        return Future.value(true);
      }
    } catch (e) {
      // print("Background Fetch Error: $e");
    }

    return Future.value(true);
  });
}

void _checkThreshold(Map<String, dynamic> data, Map<String, dynamic> settings,
    String key, String label, String unit, int notifId) async {
  if (!settings.containsKey(key)) return;

  final config = settings[key];
  if (config['enabled'] != true) return;

  double value = double.tryParse(data[key].toString()) ?? 0.0;
  double min = config['min'] ?? 0.0;
  double max = config['max'] ?? 100.0;

  if (value < min) {
    await NotificationService.showNotification(
      id: notifId,
      title: 'Low $label Alert! ⚠️',
      body:
          'Current $label ($value$unit) is below your minimum threshold of $min$unit.',
    );
  } else if (value > max) {
    await NotificationService.showNotification(
      id: notifId,
      title: 'High $label Alert! 🚨',
      body:
          'Current $label ($value$unit) exceeded your maximum threshold of $max$unit.',
    );
  }
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static void registerPeriodicTask() {
    Workmanager().registerPeriodicTask(
      "1",
      "fetchFieldData",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static void cancelAll() {
    Workmanager().cancelAll();
  }
}
