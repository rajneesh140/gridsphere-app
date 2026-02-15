import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; // Add intl package to pubspec.yaml for date formatting
import '../session_manager/session_manager.dart';

// ---------------------------------------------------------------------------
// 1. DATA MODEL (Matches ReadingModel.php lines 108-109)
// ---------------------------------------------------------------------------
class Reading {
  final String deviceId;
  final String timestamp;

  // Environmental
  final double pm25;
  final double tvoc;
  final double aqi;
  final double co2;

  // Weather
  final double temp;
  final double humidity;
  final double pressure;
  final double rain;
  final double windSpeed;
  final double windDirection;
  final double light;
  final double altitude;

  // Agriculture / Soil
  final double soilTemp;
  final double soilMoisture; // mapped from 'surface_humidity' usually
  final double depthTemp;
  final double depthHum;
  final String leafWetness;  // converted from 0/1 to "Dry"/"Wet"

  Reading({
    required this.deviceId,
    required this.timestamp,
    this.pm25 = 0.0,
    this.tvoc = 0.0,
    this.aqi = 0.0,
    this.co2 = 0.0,
    this.temp = 0.0,
    this.humidity = 0.0,
    this.pressure = 0.0,
    this.rain = 0.0,
    this.windSpeed = 0.0,
    this.windDirection = 0.0,
    this.light = 0.0,
    this.altitude = 0.0,
    this.soilTemp = 0.0,
    this.soilMoisture = 0.0,
    this.depthTemp = 0.0,
    this.depthHum = 0.0,
    this.leafWetness = "Dry",
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return Reading(
      deviceId: json['d_id']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',

      // Air Quality
      pm25: toDouble(json['pm25']),
      tvoc: toDouble(json['tvoc']),
      aqi: toDouble(json['aqi']),

      // Weather
      temp: toDouble(json['temp']),
      humidity: toDouble(json['humidity']),
      pressure: toDouble(json['pressure']),
      rain: toDouble(json['rainfall']),
      windSpeed: toDouble(json['wind_speed']),
      windDirection: toDouble(json['wind_direction']),
      light: toDouble(json['light_intensity']),
      altitude: toDouble(json['altitude']),

      // Agri (Mapping surface/depth to clear names)
      soilTemp: toDouble(json['surface_temp']),
      soilMoisture: toDouble(json['surface_humidity']),
      depthTemp: toDouble(json['depth_temp']),
      depthHum: toDouble(json['depth_humidity']),

      // Leaf Wetness: Backend sends 1 or 0 usually
      leafWetness: (json['leafwetness']?.toString() == "1") ? "Wet" : "Dry",
    );
  }
}

// ---------------------------------------------------------------------------
// 2. SERVICE CLASS (Connects to Devices.php)
// ---------------------------------------------------------------------------
class ReadingsService {
  final String _baseUrl = "https://gridsphere.in/station/api";

  /// 1. Get LIVE DATA (Latest Reading)
  /// Backend: Devices.php -> liveData() [Line 34]
  Future<Reading?> fetchLive(String deviceId) async {
    final url = Uri.parse('$_baseUrl/live-data/$deviceId');

    try {
      final response = await http.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == true && json['data'] is List && json['data'].isNotEmpty) {
          return Reading.fromJson(json['data'][0]);
        }
      }
    } catch (e) {
      debugPrint("Error fetching live data: $e");
    }
    return null;
  }

  /// 2. Get LAST 7 DAYS HISTORY
  /// Backend: Devices.php -> history() [Line 41]
  /// We use range='custom' [Line 48-50] to calculate exactly 7 days back.
  Future<List<Reading>> fetchLast7Days(String deviceId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Format dates as YYYY-MM-DD (Required by backend Line 116-117)
    final formatter = DateFormat('yyyy-MM-dd');
    final String toDate = formatter.format(now);
    final String fromDate = formatter.format(sevenDaysAgo);

    // URL: /history/{id}?range=custom&from=...&to=...
    final url = Uri.parse(
        '$_baseUrl/history/$deviceId?range=custom&from=$fromDate&to=$toDate'
    );

    try {
      final response = await http.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Backend returns { status: true, data: [...] } [Line 54]
        if (json['status'] == true && json['data'] is List) {
          return (json['data'] as List)
              .map((item) => Reading.fromJson(item))
              .toList();
        }
      } else {
        debugPrint("History Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
    return [];
  }

  // Helper for headers (Cookie is critical for Auth)
  Map<String, String> _getHeaders() {
    return {
      'Cookie': SessionManager().sessionCookie, // Required by backend [Line 35 & 42]
      'User-Agent': 'FlutterApp',
      'Accept': 'application/json',
    };
  }
}