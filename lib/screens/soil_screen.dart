import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http; // Added http
import 'dart:convert'; // Added json
import 'chat_screen.dart';
import 'alerts_screen.dart';
// Detailed screens imports removed as they are no longer linked in the new design
import 'dart:math'; // For fallback mock data
import 'package:intl/intl.dart'; // For formatting time

class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

class SoilScreen extends StatefulWidget {
  final String sessionCookie;
  final String deviceId; // To fetch data if needed
  final Map<String, dynamic>? sensorData; // To display current values immediately
  final double latitude;
  final double longitude;

  const SoilScreen({
    super.key, 
    required this.sessionCookie,
    this.deviceId = "",
    this.sensorData,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  @override
  State<SoilScreen> createState() => _SoilScreenState();
}

class _SoilScreenState extends State<SoilScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 3; // 3 corresponds to "Soil" in BottomNavBar

  // Mock data for spray timing
  List<Map<String, dynamic>> _sprayForecast = [];
  bool _isLoadingForecast = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Use API if lat/lon available, else fallback
    if (widget.latitude != 0.0 && widget.longitude != 0.0) {
      _fetchForecastData();
    } else {
      _generateMockSprayData();
    }
  }

  Future<void> _fetchForecastData() async {
    final apiKey = "371b716c25a9e70d9b96b6dc52443a7a";
    // cnt=8 gives 24 hours (8 * 3 hours) from the API.
    // We will use these 3-hour blocks directly.
    final url = Uri.parse("https://api.openweathermap.org/data/2.5/forecast?lat=${widget.latitude}&lon=${widget.longitude}&cnt=8&appid=$apiKey&units=metric"); 

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['list'];
        
        List<Map<String, dynamic>> forecast = [];
        
        for (var item in list) {
           DateTime time = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
           
           double temp = (item['main']['temp'] as num).toDouble();
           double humidity = (item['main']['humidity'] as num).toDouble();
           
           // Wind speed from API is in m/s (metric)
           double windSpeedMps = (item['wind']['speed'] as num).toDouble();
           double windSpeedKph = windSpeedMps * 3.6; 
           
           String weatherDesc = "";
           if (item['weather'] != null && (item['weather'] as List).isNotEmpty) {
             weatherDesc = item['weather'][0]['description'].toString().toLowerCase();
           }
           
           // Logic: No Spray if Rain or Wind > 3 m/s
           bool isRaining = weatherDesc.contains('rain') || weatherDesc.contains('drizzle') || weatherDesc.contains('storm');
           bool tooWindy = windSpeedMps > 3.0; // > 3 m/s
           
           // Modified Logic: Removed humidity check (> 40)
           bool canSpray = !isRaining && !tooWindy && (temp < 28); 
           
           String reason = "";
           if (isRaining) reason = "Rain";
           else if (tooWindy) reason = "Windy";
           else if (temp >= 28) reason = "Too Hot";
           
           forecast.add({
             "time": time,
             "temp": temp,
             "humidity": humidity,
             "wind": windSpeedKph, // Display in kph usually better for users, but logic used m/s
             "windMps": windSpeedMps,
             "canSpray": canSpray,
             "reason": reason,
             "desc": weatherDesc,
           });
        }

        if (mounted) {
          setState(() {
            _sprayForecast = forecast;
            _isLoadingForecast = false;
          });
        }
      } else {
        debugPrint("Weather API Error: ${response.statusCode}");
        _generateMockSprayData(); 
      }
    } catch (e) {
      debugPrint("Weather API Exception: $e");
      _generateMockSprayData();
    }
  }

  void _generateMockSprayData() {
    // This is now a fallback only if API fails completely
    final random = Random();
    DateTime now = DateTime.now();
    // Round up to nearest 3 hours
    int hour = now.hour;
    int nextHour = (hour ~/ 3 + 1) * 3; 
    // Handle day overflow if needed, but simple addition works
    DateTime startTime = DateTime(now.year, now.month, now.day, nextHour, 0);
    if (startTime.isBefore(now)) startTime = startTime.add(const Duration(hours: 3));
    
    List<Map<String, dynamic>> mockData = [];
    for (int i = 0; i < 8; i++) { // 8 blocks of 3 hours = 24 hours
      DateTime time = startTime.add(Duration(hours: i * 3));
      double temp = 20 + random.nextDouble() * 10; 
      double humidity = 40 + random.nextDouble() * 40; 
      double windMps = random.nextDouble() * 5; // 0-5 m/s
      double windKph = windMps * 3.6;
      
      bool isRaining = random.nextDouble() > 0.8; // 20% chance rain
      bool tooWindy = windMps > 3.0;
      
      bool canSpray = !isRaining && !tooWindy && (temp < 28);
      String reason = isRaining ? "Rain" : (tooWindy ? "Windy" : "");

      mockData.add({
        "time": time,
        "temp": temp,
        "humidity": humidity,
        "wind": windKph,
        "windMps": windMps,
        "canSpray": canSpray,
        "reason": reason,
        "desc": isRaining ? "light rain" : "clear sky",
      });
    }
    
    if (mounted) {
      setState(() {
        _sprayForecast = mockData;
        _isLoadingForecast = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF166534), // Brand Green
      appBar: AppBar(
        backgroundColor: const Color(0xFF166534),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Soil Health",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Downloading Soil Health Report..."))
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.download, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Report",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF166534),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: "Spray Timing"),
                Tab(text: "Soil Parameters"),
              ],
            ),
          ),
        ),
      ),
      
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
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF166534),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        onTap: (index) {
          if (index == 2) return; // Dummy item
          
          if (index == 0) {
            Navigator.pop(context); // Go back to Dashboard
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AlertsScreen()),
            ).then((_) => setState(() => _selectedIndex = 3));
          } else {
             setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(LucideIcons.shieldCheck), label: "Protection"),
          BottomNavigationBarItem(icon: SizedBox(height: 24), label: ""),
          BottomNavigationBarItem(icon: Icon(LucideIcons.layers), label: "Soil"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: "Alerts"),
        ],
      ),

      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- Spray Timing Tab ---
              _buildSprayTimingContent(),
              // --- Soil Parameters Tab ---
              _buildSoilParametersContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSprayTimingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "Spray Recommendations",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Forecast (3-hour intervals)",
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          
          if (_isLoadingForecast) 
             const Center(child: Padding(
               padding: EdgeInsets.all(20.0),
               child: CircularProgressIndicator(color: Color(0xFF166534)),
             ))
          else 
            // List view of blocks one after another
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sprayForecast.length,
              itemBuilder: (context, index) {
                final slot = _sprayForecast[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildSprayBlock(slot),
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSprayBlock(Map<String, dynamic> slot) {
    bool canSpray = slot['canSpray'];
    String reason = slot['reason'] ?? "";
    
    Color statusColor = canSpray ? const Color(0xFF22C55E) : const Color(0xFFEF4444); // Green or Red
    Color bgColor = canSpray ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2); // Light Green or Light Red
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(slot['time']),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(slot['time']),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Metrics
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniCondition(LucideIcons.thermometer, "${slot['temp'].toStringAsFixed(0)}°C"),
                _buildMiniCondition(LucideIcons.droplets, "${slot['humidity'].toStringAsFixed(0)}%"),
                _buildMiniCondition(LucideIcons.wind, "${slot['windMps'].toStringAsFixed(1)} m/s"),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Signal Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      canSpray ? LucideIcons.checkCircle : LucideIcons.xCircle,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      canSpray ? "SPRAY" : "AVOID",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (!canSpray && reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      reason,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCondition(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildSoilParametersContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "Soil Composition & Nutrients",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          // Additional Soil Parameters with Dummy Data
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5, // Slightly wider for text
            children: [
              _buildSimpleCard("pH Soil", "6.5", LucideIcons.testTube),
              _buildSimpleCard("EC Soil", "0.8 dS/m", LucideIcons.zap),
              _buildSimpleCard("Organic Carbon", "0.75 %", LucideIcons.leaf),
              _buildSimpleCard("N Available", "180 Kg/ha", LucideIcons.sprout),
              _buildSimpleCard("P Available", "22 Kg/ha", LucideIcons.aperture), // P icon placeholder
              _buildSimpleCard("K Available", "210 Kg/ha", LucideIcons.atom), // K icon placeholder
              _buildSimpleCard("Calcium", "4.2 cmol/Kg", LucideIcons.bone), // Calcium icon placeholder
              _buildSimpleCard("Magnesium", "1.8 cmol/Kg", LucideIcons.mountainSnow), // Mg icon placeholder
              _buildSimpleCard("S Available", "15 ppm", LucideIcons.cloudFog), // Sulfur icon placeholder
              _buildSimpleCard("Iron", "4.5 mg/Kg", LucideIcons.anchor), // Iron icon placeholder
              _buildSimpleCard("Manganese", "3.2 mg/Kg", LucideIcons.gem), // Manganese icon placeholder
              _buildSimpleCard("Copper", "0.8 mg/Kg", LucideIcons.coins), // Copper icon placeholder
              _buildSimpleCard("Zinc", "1.2 mg/Kg", LucideIcons.shield), // Zinc icon placeholder
              _buildSimpleCard("Boron", "0.5 mg/Kg", LucideIcons.flower), // Boron icon placeholder
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSimpleCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF166534).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF166534)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13, // Increased size
                    color: Colors.grey[700], // Darker text
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 2.0),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}