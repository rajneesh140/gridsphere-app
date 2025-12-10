import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'dart:math'; // Imported for random data generation
import 'overview_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart'; 
import 'temperature_details_screen.dart'; // Import the new screen

// Fallback GoogleFonts class... (same as before)
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
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedDeviceId = "2";
  Map<String, dynamic>? sensorData;
  bool isLoading = true;
  Timer? _timer;
  int _selectedIndex = 0; 

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (sensorData == null) {
      setState(() => isLoading = true);
    }
    
    await Future.delayed(const Duration(seconds: 1));
    
    final random = Random();

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

    setState(() {
      sensorData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF166534),
        child: const Icon(LucideIcons.bot, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF166534),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: "Sensors",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: "Alerts",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(context),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF166534)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            "Field Conditions",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFieldConditionsGrid(),
                          const SizedBox(height: 80), 
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
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
              const Icon(
                Icons.public, 
                size: 32,
                color: Color(0xFF166534),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Grid Sphere Pvt. Ltd.",
                    style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "AgriTech",
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.grey, size: 24),
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
      childAspectRatio: 0.9, 
      children: [
        // 1. Air Temp - CLICKABLE (Links to new screen)
        _ConditionCard(
          title: "Air Temp",
          value: "${sensorData?['air_temp']}°C",
          icon: LucideIcons.thermometer,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          child: _MiniLineChart(color: const Color(0xFF2E7D32)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TemperatureDetailsScreen(sensorData: sensorData),
              ),
            );
          },
        ),
        
        // 2. Humidity
        _ConditionCard(
          title: "Humidity",
          value: "${sensorData?['humidity']}%",
          icon: LucideIcons.droplets,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          child: _MiniLineChart(color: const Color(0xFF2E7D32)),
        ),

        // 3. Leaf Wetness
        _ConditionCard(
          title: "Leaf",
          customContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Leaf Wetness",
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "${sensorData?['leaf_wetness']}",
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
                ],
              )
            ],
          ),
          icon: LucideIcons.leaf,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
        ),

        // 4. Rainfall
        _ConditionCard(
          title: "Today's\nRainfall",
          subtitle: "Today",
          value: "${sensorData?['rainfall']} mm",
          icon: LucideIcons.cloudRain,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
        ),

        // 5. Light Intensity
        _ConditionCard(
          title: "Light\nIntensity",
          value: "${sensorData?['light_intensity']} lx",
          icon: LucideIcons.sun,
          iconBg: const Color(0xFFFFFDE7),
          iconColor: const Color(0xFFFBC02D),
        ),

        // 6. Wind
        _ConditionCard(
          title: "Wind",
          value: "${sensorData?['wind']} km/h",
          icon: LucideIcons.wind,
          iconBg: const Color(0xFFE0F7FA),
          iconColor: const Color(0xFF0097A7),
        ),

        // 7. Pressure
        _ConditionCard(
          title: "Pressure",
          value: "${sensorData?['pressure']} hPa",
          icon: LucideIcons.gauge,
          iconBg: const Color(0xFFF3E5F5),
          iconColor: const Color(0xFF7B1FA2),
        ),

        // 8. Depth Temp
        _ConditionCard(
          title: "Depth Temp\n(10cm)",
          value: "${sensorData?['depth_temp']}°C",
          icon: Icons.device_thermostat, 
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
        ),

        // 9. Depth Humidity
        _ConditionCard(
          title: "Depth Hum\n(10cm)",
          value: "${sensorData?['depth_humidity']}%",
          icon: LucideIcons.droplet, 
          iconBg: const Color(0xFFE1F5FE),
          iconColor: const Color(0xFF0288D1),
        ),

        // 10. Surface Temp
        _ConditionCard(
          title: "Surf Temp",
          value: "${sensorData?['surface_temp']}°C",
          icon: Icons.thermostat,
          iconBg: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
        ),

        // 11. Surface Humidity
        _ConditionCard(
          title: "Surf Hum",
          value: "${sensorData?['surface_humidity']}%",
          icon: LucideIcons.waves,
          iconBg: const Color(0xFFEFEBE9),
          iconColor: const Color(0xFF5D4037),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 4),
              Text(
                value ?? "--",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
            if (child != null) ...[
              const Spacer(),
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
  const _MiniLineChart({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(color),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color color;
  _ChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.7, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.2);

    canvas.drawPath(path, paint);
    
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
      
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
    );
    
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}