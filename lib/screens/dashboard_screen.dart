import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http; // Add http package
import 'dart:convert'; // Add JSON decoding
import 'dart:async';
import 'dart:math'; // Imported for random data generation
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../detailed_screens/temperature_details_screen.dart';
import '../detailed_screens/humidity_details_screen.dart';
// --- IMPORT NEW SCREEN ---
import '../detailed_screens/leaf_wetness_details_screen.dart';
import 'alerts_screen.dart';

class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  // --- Receive Session Cookie from Login ---
  final String sessionCookie;
  
  const DashboardScreen({super.key, required this.sessionCookie});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedDeviceId = ""; // Start empty
  
  // --- NEW: Devices List ---
  List<dynamic> _devices = [];

  // --- Field Information State ---
  String farmerName = "--";
  String lastOnline = "--";
  String deviceStatus = "Offline";
  String deviceLocation = "--";
  
  // --- Offline State ---
  bool isDeviceOffline = false;
  
  Map<String, dynamic>? sensorData;
  // Store 24h history for all metrics using a Map
  Map<String, List<double>> historyData = {}; 
  
  bool isLoading = true;
  Timer? _timer;
  int _selectedIndex = 0;
  
  final String _baseUrl = "https://gridsphere.in/station/api";

  @override
  void initState() {
    super.initState();
    debugPrint("Dashboard initialized with Cookie: ${widget.sessionCookie}");
    _initializeData();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) => _fetchLiveData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchUserInfo(); // Fetch farmer name
    await _fetchDevices();  // Fetch device ID and location
    if (selectedDeviceId.isNotEmpty) {
      await _fetchLiveData();
      await _fetchHistoryData(); // Fetch history for the graph
    } else {
      // If fetching devices failed, load mock data so UI isn't empty
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Connection failed. Showing Offline Data."),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
         );
      }
      _loadMockData(); 
    }
  }

  // --- Helper to Switch Devices ---
  void _switchDevice(String deviceId, String location) {
    if (selectedDeviceId == deviceId) return;

    setState(() {
      selectedDeviceId = deviceId;
      deviceLocation = location;
      isLoading = true; // Show loading while fetching new device data
      sensorData = null; // Clear old data
      
      // --- Reset Status Indicators for the new device ---
      isDeviceOffline = false;
      deviceStatus = "Checking...";
      lastOnline = "--";
    });
    
    // Fetch data for the new device (logic will re-run inside _fetchLiveData)
    _fetchLiveData();
    _fetchHistoryData();
  }

  // Helper to load mock data if API fails
  void _loadMockData() {
    debugPrint("⚠️ Loading Mock Data (Fallback)");
    final random = Random();
    
    // Mock Devices List
    final mockDevices = [
      {'d_id': '2', 'farm_name': 'Field A (Apple)', 'location': 'Himachal Pradesh'},
      {'d_id': '3', 'farm_name': 'Field B (Cherry)', 'location': 'Kashmir Valley'},
    ];

    final data = {
      "air_temp": double.parse((24.0 + random.nextDouble() * 2 - 1).toStringAsFixed(1)),
      "humidity": 65 + random.nextInt(6) - 3,
      "leaf_wetness": random.nextDouble() > 0.9 ? "Wet" : "Dry",
      "soil_temp": double.parse((20.0 + random.nextDouble()).toStringAsFixed(1)),
      "soil_moisture": 30 + random.nextInt(5),
      "rainfall": double.parse((5.2 + (random.nextDouble() * 0.2)).toStringAsFixed(1)),
      "light_intensity": 850 + random.nextInt(50) - 25,
      "wind": double.parse((12.0 + random.nextDouble() * 3).toStringAsFixed(1)),
      "pressure": 1013 + random.nextInt(4) - 2,
      "depth_temp": double.parse((22.5 + random.nextDouble() * 0.5).toStringAsFixed(1)),
      "depth_humidity": double.parse((60.0 + random.nextDouble() * 2).toStringAsFixed(1)),
      "surface_temp": double.parse((26.0 + random.nextDouble()).toStringAsFixed(1)),
      "surface_humidity": double.parse((55.0 + random.nextDouble() * 2).toStringAsFixed(1)),
    };

    // Mock history data generation
    List<double> genList(double base, double range) {
      return List.generate(24, (index) => base + (random.nextDouble() * range - range/2));
    }

    Map<String, List<double>> mockHistory = {
      "air_temp": genList(24.0, 5.0),
      "humidity": genList(65.0, 10.0),
      "leaf_wetness": List.generate(24, (_) => random.nextBool() ? 1.0 : 0.0),
      "soil_temp": genList(20.0, 2.0),
      "soil_moisture": genList(30.0, 5.0),
      "rainfall": genList(0.5, 1.0).map((e) => e < 0 ? 0.0 : e).toList(),
      "light_intensity": genList(800.0, 200.0),
      "wind": genList(10.0, 5.0),
      "pressure": genList(1013.0, 5.0),
      "depth_temp": genList(22.0, 2.0),
      "depth_humidity": genList(60.0, 5.0),
      "surface_temp": genList(26.0, 3.0),
      "surface_humidity": genList(55.0, 5.0),
    };

    if (mounted) {
      setState(() {
        sensorData = data;
        historyData = mockHistory;
        isLoading = false;
        _devices = mockDevices; // Populate dropdown
        
        // Mock Field Information
        farmerName = "Aditya Farm";
        lastOnline = "Today, 10:30 AM";
        deviceStatus = "Online";
        isDeviceOffline = false; // Assume online for mock
        
        if (selectedDeviceId.isEmpty) {
             selectedDeviceId = mockDevices[0]['d_id']!;
             deviceLocation = mockDevices[0]['farm_name']!;
        }
      });
    }
  }

  // --- Fetch User Info for Farmer Name ---
  Future<void> _fetchUserInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/checkSession'),
        headers: {
          'Cookie': widget.sessionCookie,
          'User-Agent': 'FlutterApp',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            farmerName = data['username']?.toString() ?? "Farmer";
          });
        }
      }
    } catch (e) {
      debugPrint("Exception fetching user info: $e");
    }
  }

  Future<void> _fetchDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getDevices'),
        headers: {
          'Cookie': widget.sessionCookie,
          'User-Agent': 'FlutterApp', 
          'Accept': 'application/json',
        },
      );

      debugPrint("GetDevices Status: ${response.statusCode}");
      debugPrint("GetDevices Body: ${response.body}");

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> deviceList = [];

        if (data is List) {
          deviceList = data;
        } else if (data is Map) {
           if (data['data'] is List) {
             deviceList = data['data'];
           } else if (data['devices'] is List) {
             deviceList = data['devices'];
           }
        }

        if (deviceList.isNotEmpty) {
           setState(() {
             // --- Update Devices List ---
             _devices = deviceList;

             var device = deviceList[0];
             selectedDeviceId = device['d_id'].toString();
             // Try to get location from device info if available, else fallback
             deviceLocation = device['farm_name']?.toString() ?? device['location']?.toString() ?? "Field A";
           });
           debugPrint("✅ Device ID Found: $selectedDeviceId");
        } else {
           debugPrint("⚠️ No devices found in response data.");
        }
      } else {
        debugPrint("Error fetching devices: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Exception fetching devices: $e");
    }
  }

  Future<void> _fetchLiveData() async {
    if (selectedDeviceId.isEmpty || selectedDeviceId.contains("Demo")) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/live-data/$selectedDeviceId'),
        headers: {
          'Cookie': widget.sessionCookie,
          'User-Agent': 'FlutterApp',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        List<dynamic> readings = [];
        if (jsonResponse is List) {
          readings = jsonResponse;
        } else if (jsonResponse['data'] is List) {
          readings = jsonResponse['data'];
        }

        if (readings.isNotEmpty) {
          final reading = readings[0];
          
          if (mounted) {
            setState(() {
              // --- Time Logic for Offline Check ---
              String timeStr = reading['timestamp']?.toString() ?? "";
              lastOnline = timeStr;
              
              // Calculate difference
              bool isOffline = false;
              if (timeStr.isNotEmpty) {
                try {
                   // Ensure ISO format for parsing (replace space with T if needed)
                   DateTime readingTime = DateTime.parse(timeStr.replaceAll(' ', 'T'));
                   Duration diff = DateTime.now().difference(readingTime);
                   
                   // Check if older than 90 minutes
                   if (diff.inMinutes > 90) {
                     isOffline = true;
                   }
                } catch (e) {
                   debugPrint("Date Parse Error: $e");
                }
              }

              isDeviceOffline = isOffline;
              deviceStatus = isOffline ? "Offline" : "Online";
              
              sensorData = {
                "air_temp": double.tryParse(reading['temp'].toString()) ?? 0.0,
                "humidity": double.tryParse(reading['humidity'].toString()) ?? 0.0,
                "leaf_wetness": reading['leafwetness']?.toString() ?? "Dry",
                "soil_temp": double.tryParse(reading['depth_temp'].toString()) ?? 0.0,
                "soil_moisture": double.tryParse(reading['surface_humidity'].toString()) ?? 0.0,
                "rainfall": double.tryParse(reading['rainfall'].toString()) ?? 0.0,
                "light_intensity": double.tryParse(reading['light_intensity'].toString()) ?? 0.0,
                "wind": double.tryParse(reading['wind_speed'].toString()) ?? 0.0,
                "pressure": double.tryParse(reading['pressure'].toString()) ?? 0.0,
                "depth_temp": double.tryParse(reading['depth_temp'].toString()) ?? 0.0,
                "depth_humidity": double.tryParse(reading['depth_humidity'].toString()) ?? 0.0,
                "surface_temp": double.tryParse(reading['surface_temp'].toString()) ?? 0.0,
                "surface_humidity": double.tryParse(reading['surface_humidity'].toString()) ?? 0.0,
              };
              isLoading = false;
            });
          }
        } else {
             // No readings might mean offline or new device
             if (mounted) {
               setState(() {
                 deviceStatus = "Offline / No Data";
                 isDeviceOffline = true;
                 isLoading = false;
               });
             }
        }
      } else {
        debugPrint("Error fetching live data: ${response.statusCode}");
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Exception fetching live data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchHistoryData() async {
    if (selectedDeviceId.isEmpty || selectedDeviceId.contains("Demo")) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/devices/$selectedDeviceId/history?range=daily'),
        headers: {
          'Cookie': widget.sessionCookie,
          'User-Agent': 'FlutterApp',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        List<dynamic> readings = [];
        if (jsonResponse is List) {
          readings = jsonResponse;
        } else if (jsonResponse['data'] is List) {
          readings = jsonResponse['data'];
        }

        if (readings.isNotEmpty) {
          List<double> extractList(String key) {
            return readings.map<double>((r) {
              return double.tryParse(r[key].toString()) ?? 0.0;
            }).toList();
          }

          Map<String, List<double>> newHistory = {};
          
          newHistory['air_temp'] = extractList('temp');
          newHistory['humidity'] = extractList('humidity');
          newHistory['leaf_wetness'] = extractList('leafwetness'); 
          newHistory['soil_temp'] = extractList('depth_temp'); 
          newHistory['soil_moisture'] = extractList('surface_humidity'); 
          newHistory['rainfall'] = extractList('rainfall');
          newHistory['light_intensity'] = extractList('light_intensity');
          newHistory['wind'] = extractList('wind_speed');
          newHistory['pressure'] = extractList('pressure');
          newHistory['depth_temp'] = extractList('depth_temp');
          newHistory['depth_humidity'] = extractList('depth_humidity');
          newHistory['surface_temp'] = extractList('surface_temp');
          newHistory['surface_humidity'] = extractList('surface_humidity');

          if (newHistory['air_temp']!.isNotEmpty) {
             newHistory.forEach((key, list) {
               newHistory[key] = list.reversed.toList();
             });
             
             if (mounted) {
               setState(() {
                 historyData = newHistory;
               });
             }
          }
        }
      }
    } catch (e) {
      debugPrint("Exception fetching history data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF166534), 
      
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

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2) return;
          setState(() => _selectedIndex = index);
          if (index == 4) { 
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AlertsScreen()),
            ).then((_) => setState(() => _selectedIndex = 0));
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF166534),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.shieldCheck), label: "Protection"),
          BottomNavigationBarItem(icon: SizedBox(height: 24), label: ""),
          BottomNavigationBarItem(icon: Icon(LucideIcons.layers), label: "Soil"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: "Alerts"),
        ],
      ),

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildCustomHeader(context),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ClipRRect( 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF166534)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            // --- NEW: Offline Warning Widget ---
                            if (isDeviceOffline) _buildOfflineWarning(),
                            
                            _buildFieldInfoBox(),
                            const SizedBox(height: 24),
                            
                            Text(
                              "Field Conditions",
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFieldConditionsGrid(),
                            const SizedBox(height: 80), 
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets (Header, Grid, Cards) ---

  // --- Warning Widget ---
  Widget _buildOfflineWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Device Offline",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Data is stale. Please contact the Grid Sphere service team.",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.sprout, size: 18, color: Color(0xFF166534)),
              ),
              const SizedBox(width: 10),
              Text(
                "Field Information", 
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow("Device ID:", selectedDeviceId), 
                    const SizedBox(height: 12),
                    _buildInfoRow("Farmer Name:", farmerName), 
                    const SizedBox(height: 12),
                    _buildInfoRow("Location:", deviceLocation), 
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pass isOffline to style it red if needed
                    _buildStatusRow("Status:", deviceStatus, isError: isDeviceOffline), 
                    const SizedBox(height: 12),
                    _buildInfoRow("Last Online:", lastOnline), 
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 2),
        // --- FittedBox to handle text overflow ---
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, {bool isError = false}) {
    // If we passed explicit error flag, use red. Otherwise check text.
    final bool isOnline = !isError && value.toLowerCase().contains("online");
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isOnline ? Icons.check_circle : Icons.error_outline, 
              size: 14, 
              color: isOnline ? const Color(0xFF22C55E) : Colors.red
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13, 
                  fontWeight: FontWeight.w600, 
                  color: isOnline ? const Color(0xFF15803D) : Colors.red
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/logo.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.public, 
                      size: 24,
                      color: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Grid Sphere Pvt. Ltd.",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  
                  // --- Device Selector Toggle ---
                  if (_devices.isNotEmpty)
                    PopupMenuButton<String>(
                      onSelected: (String id) {
                         final device = _devices.firstWhere((d) => d['d_id'].toString() == id);
                         String name = device['farm_name']?.toString() ?? "Field ${device['d_id']}";
                         _switchDevice(id, name);
                      },
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (BuildContext context) {
                        return _devices.map((device) {
                          return PopupMenuItem<String>(
                            value: device['d_id'].toString(),
                            child: Text(
                              device['farm_name']?.toString() ?? "Device ${device['d_id']}",
                              style: GoogleFonts.inter(color: Colors.black87),
                            ),
                          );
                        }).toList();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              deviceLocation, 
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                        ],
                      ),
                    )
                  else
                    Text(
                      "AgriTech",
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(sessionCookie: widget.sessionCookie),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFieldConditionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      // --- Adjusted childAspectRatio to 1.0 (Compact Square) ---
      childAspectRatio: 1.0, 
      children: [
        _ConditionCard(
          title: "Air Temp",
          value: "${sensorData?['air_temp']}°C",
          icon: LucideIcons.thermometer,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          child: _MiniLineChart(color: const Color(0xFF2E7D32), dataPoints: historyData['air_temp'] ?? []),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TemperatureDetailsScreen(
                  sensorData: sensorData,
                  deviceId: selectedDeviceId,
                  sessionCookie: widget.sessionCookie,
                )
              ),
            );
          },
        ),
        _ConditionCard(
          title: "Humidity",
          value: "${sensorData?['humidity']}%",
          icon: LucideIcons.droplets,
          iconBg: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF0288D1),
          child: _MiniLineChart(color: const Color(0xFF0288D1), dataPoints: historyData['humidity'] ?? []),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HumidityDetailsScreen(
                  sensorData: sensorData,
                  deviceId: selectedDeviceId,
                  sessionCookie: widget.sessionCookie,
              )),
            );
          },
        ),
        _ConditionCard(
          title: "Leaf Wetness",
          customContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Text("Leaf Wetness", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF374151))),
              const SizedBox(height: 4), 
              Row(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "${sensorData?['leaf_wetness']}",
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF111827))
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
                ],
              )
            ],
          ),
          icon: LucideIcons.leaf,
          iconBg: const Color(0xFFDCFCE7),
          iconColor: const Color(0xFF15803D),
          child: _MiniLineChart(color: const Color(0xFF15803D), dataPoints: historyData['leaf_wetness'] ?? []),
          onTap: () {
             Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LeafWetnessDetailsScreen(
                  sensorData: sensorData,
                  deviceId: selectedDeviceId,
                  sessionCookie: widget.sessionCookie,
              )),
            );
          }
        ),
        
        // --- Remaining Cards ---
        _ConditionCard(
          title: "Today's\nRainfall",
          subtitle: "Today",
          value: "${sensorData?['rainfall']} mm",
          icon: LucideIcons.cloudRain,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0EA5E9),
          child: _MiniLineChart(color: const Color(0xFF0EA5E9), dataPoints: historyData['rainfall'] ?? []),
        ),
        _ConditionCard(
          title: "Light\nIntensity",
          value: "${sensorData?['light_intensity']} lx",
          icon: LucideIcons.sun,
          iconBg: const Color(0xFFFFFDE7),
          iconColor: const Color(0xFFFBC02D),
          child: _MiniLineChart(color: const Color(0xFFFBC02D), dataPoints: historyData['light_intensity'] ?? []),
        ),
        _ConditionCard(
          title: "Wind",
          value: "${sensorData?['wind']} km/h",
          icon: LucideIcons.wind,
          iconBg: const Color(0xFFE0F7FA),
          iconColor: const Color(0xFF0097A7),
          child: _MiniLineChart(color: const Color(0xFF0097A7), dataPoints: historyData['wind'] ?? []),
        ),
        _ConditionCard(
          title: "Pressure",
          value: "${sensorData?['pressure']} hPa",
          icon: LucideIcons.gauge,
          iconBg: const Color(0xFFF3E5F5),
          iconColor: const Color(0xFF7B1FA2),
          child: _MiniLineChart(color: const Color(0xFF7B1FA2), dataPoints: historyData['pressure'] ?? []),
        ),
        _ConditionCard(
          title: "Depth Temp\n(10cm)",
          value: "${sensorData?['depth_temp']}°C",
          icon: Icons.device_thermostat, 
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          child: _MiniLineChart(color: const Color(0xFF2E7D32), dataPoints: historyData['depth_temp'] ?? []),
        ),
        _ConditionCard(
          title: "Depth Hum\n(10cm)",
          value: "${sensorData?['depth_humidity']}%",
          icon: LucideIcons.droplet, 
          iconBg: const Color(0xFFE1F5FE),
          iconColor: const Color(0xFF0288D1),
          child: _MiniLineChart(color: const Color(0xFF0288D1), dataPoints: historyData['depth_humidity'] ?? []),
        ),
        _ConditionCard(
          title: "Surf Temp",
          value: "${sensorData?['surface_temp']}°C",
          icon: Icons.thermostat,
          iconBg: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          child: _MiniLineChart(color: const Color(0xFFD32F2F), dataPoints: historyData['surface_temp'] ?? []),
        ),
        _ConditionCard(
          title: "Surf Hum",
          value: "${sensorData?['surface_humidity']}%",
          icon: LucideIcons.waves,
          iconBg: const Color(0xFFEFEBE9),
          iconColor: const Color(0xFF5D4037),
          child: _MiniLineChart(color: const Color(0xFF5D4037), dataPoints: historyData['surface_humidity'] ?? []),
        ),
      ],
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final String title;
  final String? value;
  final String? subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Widget? child;
  final Widget? customContent;
  final VoidCallback? onTap;

  const _ConditionCard({
    required this.title,
    this.value,
    this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.child,
    this.customContent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        // --- Reduced padding for better fit on small cards ---
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  // --- Reduced Icon padding ---
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12, // Reduced font size
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (customContent != null)
              Expanded(child: customContent!)
            else ...[
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                ),
              const SizedBox(height: 4),
              // --- Wrapped Value in FittedBox ---
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value ?? "--",
                  style: GoogleFonts.inter(
                    fontSize: 22, // Slightly reduced font size
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
            // Push content to the bottom using Spacer if no custom content
            if (child != null) ...[
               const Spacer(), 
               const SizedBox(height: 4),
               child!,
            ]
          ],
        ),
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final Color color;
  final List<double> dataPoints; // Receive actual data
  const _MiniLineChart({required this.color, required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25, // --- Reduced graph height to 25 ---
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(color, dataPoints),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color color;
  final List<double> dataPoints;
  _ChartPainter(this.color, this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    if (dataPoints.isEmpty) {
        // Fallback smooth curve if no data yet
        path.moveTo(0, size.height);
        path.quadraticBezierTo(size.width * 0.25, size.height * 0.7, size.width * 0.5, size.height * 0.5);
        path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.2);
    } else {
        // Normalize points to fit the box
        double minVal = dataPoints.reduce(min);
        double maxVal = dataPoints.reduce(max);
        double range = maxVal - minVal;
        if (range == 0) range = 1; // Prevent division by zero

        double stepX = size.width / (dataPoints.length - 1);
        
        for (int i = 0; i < dataPoints.length; i++) {
            double normalizedY = 1.0 - ((dataPoints[i] - minVal) / range);
            // Add some padding so line doesn't hit exact edges (0.1 to 0.9)
            double y = size.height * (0.1 + (normalizedY * 0.8));
            
            if (i == 0) {
                path.moveTo(0, y);
            } else {
                path.lineTo(i * stepX, y);
            }
        }
    }

    canvas.drawShadow(path, color.withOpacity(0.2), 2.0, true);
    
    canvas.drawPath(path, paint);
    
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
    );
    
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Repaint when data changes
}