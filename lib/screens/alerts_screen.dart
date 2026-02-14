import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'chat_screen.dart';
import '../session_manager/session_manager.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../widgets/custom_bottom_nav_bar.dart'; // Import CustomBottomNavBar
import '../widgets/home_pop_scope.dart'; // Import HomePopScope

class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

class AlertsScreen extends StatefulWidget {
  // Removed sessionCookie from constructor
  final String deviceId;
  final Map<String, dynamic>? sensorData;
  final double latitude;
  final double longitude;

  const AlertsScreen({
    super.key,
    this.deviceId = "",
    this.sensorData,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // int _selectedIndex = 4; // Managed by CustomBottomNavBar
  bool _isLoading = true;

  // Controllers for text inputs
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};

  // Configuration Data Source
  Map<String, dynamic> _alertConfigs = {
    'temp': {'enabled': false, 'min': 10.0, 'max': 35.0},
    'humidity': {'enabled': false, 'min': 30.0, 'max': 80.0},
    'surface_humidity': {'enabled': false, 'min': 20.0, 'max': 60.0},
    'rainfall': {'enabled': false, 'min': 0.0, 'max': 50.0},
    'light_intensity': {'enabled': false, 'min': 0.0, 'max': 10000.0},
    'wind': {'enabled': false, 'min': 0.0, 'max': 20.0},
    'pressure': {'enabled': false, 'min': 900.0, 'max': 1100.0},
  };

  // UI Display definitions
  final List<String> _sensorDisplayNames = [
    'Temperature',
    'Humidity',
    'Soil Moisture',
    'Rainfall',
    'Light Intensity',
    'Wind Speed',
    'Pressure',
  ];

  final Map<String, String> _displayToKey = {
    'Temperature': 'temp',
    'Humidity': 'humidity',
    'Soil Moisture': 'surface_humidity',
    'Rainfall': 'rainfall',
    'Light Intensity': 'light_intensity',
    'Wind Speed': 'wind',
    'Pressure': 'pressure',
  };

  final Map<String, IconData> _sensorIcons = {
    'Temperature': Icons.thermostat,
    'Humidity': Icons.water_drop,
    'Soil Moisture': LucideIcons.layers,
    'Rainfall': Icons.cloudy_snowing,
    'Light Intensity': Icons.wb_sunny,
    'Wind Speed': Icons.air,
    'Pressure': Icons.speed,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    for (var c in _minControllers.values) {
      c.dispose();
    }
    for (var c in _maxControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Assuming SessionManager has getAlertSettings method as per your previous logic
    // If not, you might need to add it to SessionManager or use SharedPreferences directly here.
    // Using SessionManager as requested for consistency.
    String? jsonStr = await SessionManager.getAlertSettings();
    if (jsonStr != null) {
      try {
        Map<String, dynamic> saved = jsonDecode(jsonStr);
        // Merge saved settings into local config
        saved.forEach((key, value) {
          if (_alertConfigs.containsKey(key)) {
            _alertConfigs[key] = value;
          }
        });
      } catch (e) {
        debugPrint("Error loading alert settings: $e");
      }
    }

    // Initialize Controllers based on loaded configs
    for (var displayName in _sensorDisplayNames) {
      String key = _displayToKey[displayName]!;
      var config = _alertConfigs[key] ?? {'min': 0.0, 'max': 100.0};

      _minControllers[key] =
          TextEditingController(text: config['min']?.toString() ?? '');
      _maxControllers[key] =
          TextEditingController(text: config['max']?.toString() ?? '');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    bool anyEnabled = false;

    // Update _alertConfigs from Controllers
    _displayToKey.forEach((displayName, key) {
      if (_alertConfigs.containsKey(key)) {
        // Parse Min
        double? minVal = double.tryParse(_minControllers[key]?.text ?? '');
        if (minVal != null) _alertConfigs[key]['min'] = minVal;

        // Parse Max
        double? maxVal = double.tryParse(_maxControllers[key]?.text ?? '');
        if (maxVal != null) _alertConfigs[key]['max'] = maxVal;

        // Check if enabled
        if (_alertConfigs[key]['enabled'] == true) {
          anyEnabled = true;
        }
      }
    });

    // Save settings
    await SessionManager.saveAlertSettings(jsonEncode(_alertConfigs));

    // Ensure device ID is saved
    if (widget.deviceId.isNotEmpty) {
      await SessionManager.saveSelectedDevice(widget.deviceId);
    }

    // Manage Background Service
    if (anyEnabled) {
      BackgroundService.registerPeriodicTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerts updated & Monitoring Active!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      BackgroundService.cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved. Monitoring Paused.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // --- UPDATED: Use HomePopScope Wrapper ---
    return HomePopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // Light background

        // --- APP BAR ---
        appBar: AppBar(
          title: const Text(
            "Alert Configuration",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Debug Button
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.orange),
              tooltip: "Test Notification",
              onPressed: () async {
                await NotificationService.showNotification(
                  id: 101,
                  title: "Debug Alert 🛠️",
                  body: "Notification system is fully operational!",
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Test notification triggered")),
                  );
                }
              },
            ),
            // Save Button
            IconButton(
              icon: Icon(Icons.check_circle,
                  color: _isLoading ? Colors.grey : const Color(0xFF00B0FF),
                  size: 28),
              onPressed: _isLoading ? null : _saveSettings,
              tooltip: "Save Settings",
            )
          ],
        ),

        // --- FOOTER ---
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          },
          backgroundColor: const Color(0xFF166534),
          elevation: 4.0,
          shape: const CircleBorder(),
          child: const Icon(LucideIcons.bot, color: Colors.white, size: 28),
        ),

        // --- Custom Bottom Navigation Bar ---
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: 4, // Alerts is index 4
          deviceId: widget.deviceId,
          sensorData: widget.sensorData,
          // Using passed coordinates (or falling back to defaults if 0.0)
          latitude: widget.latitude != 0.0
              ? widget.latitude
              : SessionManager().latitude,
          longitude: widget.longitude != 0.0
              ? widget.longitude
              : SessionManager().longitude,
        ),

        // --- BODY ---
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF166534)))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    "Set Thresholds",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._sensorDisplayNames.map((sensor) {
                    return _buildSensorCard(sensor);
                  }).toList(),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
      ),
    );
  }

  Widget _buildSensorCard(String displayName) {
    String key = _displayToKey[displayName]!;
    bool isEnabled = _alertConfigs[key]?['enabled'] ?? false;
    Color primaryColor = const Color(0xFF166534); // Brand color

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? primaryColor.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _sensorIcons[displayName] ?? Icons.sensors,
                    color: isEnabled ? primaryColor : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  activeColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      if (_alertConfigs.containsKey(key)) {
                        _alertConfigs[key]['enabled'] = val;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (isEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildThresholdInput(
                      _minControllers[key]!,
                      "Min Limit",
                      Icons.arrow_downward_rounded,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildThresholdInput(
                      _maxControllers[key]!,
                      "Max Limit",
                      Icons.arrow_upward_rounded,
                      Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdInput(TextEditingController controller, String label,
      IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(icon, size: 16, color: color),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.5), width: 1.5),
            ),
            hintText: "--",
            hintStyle: TextStyle(color: Colors.grey.shade300),
          ),
        ),
      ],
    );
  }
}
