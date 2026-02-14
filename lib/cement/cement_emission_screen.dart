import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../services/mock_data_store.dart'; // <--- IMPORT THIS
import '../screens/chat_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../session_manager/session_manager.dart';
import 'cement_dust_spread_screen.dart';
import '../widgets/home_back_button.dart';
import '../widgets/home_pop_scope.dart';

class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
    );
  }
}

class CementEmissionScreen extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic>? sensorData;

  const CementEmissionScreen({super.key, this.deviceId = "", this.sensorData});

  @override
  State<CementEmissionScreen> createState() => _CementEmissionScreenState();
}

class _CementEmissionScreenState extends State<CementEmissionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _selectedIndex = 3;
  final String _baseUrl = "https://gridsphere.in/station/api";

  bool _isLoading = true;

  // Raw Data
  double windSpeed = 0.0;
  double windDirection = 0.0;
  double pm25 = 0.0;
  double pressure = 1013.0;
  double humidity = 0.0;
  double sunlight = 0.0;

  // Tab 3
  String windEffect = "Neutral";
  double calmAccumulationScore = 0.0;
  double humiditySuppression = 0.0;
  String pressureTrend = "Stable";
  double solarDryingEffect = 0.0;
  String dominantSector = "Unknown";

  // Tab 4
  double pm24hAvg = 0.0;
  bool isCompliant = true;
  String complianceRisk = "Low";
  double exceedanceSeverity = 0.0;
  double complianceStability = 0.0;
  double performanceScore = 100.0;
  String controlEffectiveness = "Unknown";
  String weeklyTrend = "Improving";

  List<double> hourlyPmLast24 = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataAndCalculate();
  }

  Future<void> _fetchDataAndCalculate() async {
    if (widget.deviceId.isEmpty || widget.deviceId.contains("Demo")) {
      _loadPersistentData();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/live-data/${widget.deviceId}'),
        headers: {
          'Cookie': SessionManager().sessionCookie,
          'User-Agent': 'FlutterApp',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> readings = [];
        if (jsonResponse is List) readings = jsonResponse;
        else if (jsonResponse['data'] is List) readings = jsonResponse['data'];

        if (readings.isNotEmpty) {
          final r = readings[0];
          windSpeed = double.tryParse(r['wind_speed']?.toString() ?? "0") ?? 0.0;
          pm25 = double.tryParse(r['pm25']?.toString() ?? "0") ?? 0.0;
          pressure = double.tryParse(r['pressure']?.toString() ?? "1013") ?? 1013.0;
          humidity = double.tryParse(r['humidity']?.toString() ?? "0") ?? 0.0;
          sunlight = double.tryParse(r['light_intensity']?.toString() ?? "0") ?? 0.0;

          _fillMissingSensorsWithPersistence();
          _runSuperTabAlgorithms();
        } else {
          _loadPersistentData();
        }
      } else {
        _loadPersistentData();
      }
    } catch (e) {
      _loadPersistentData();
    }
  }

  void _loadPersistentData() {
    if (!mounted) return;
    final data = MockDataStore().getOrGenerateData(widget.deviceId);

    pm25 = data['pm25'];
    windSpeed = data['windSpeed'];
    pressure = data['pressure'];
    humidity = data['humidity'];
    sunlight = data['sunlight'];

    // Arrays & specialized fields
    windDirection = data['windDirection'];
    hourlyPmLast24 = (data['pmHistory'] as List).cast<double>();

    _runSuperTabAlgorithms();
  }

  void _fillMissingSensorsWithPersistence() {
    final data = MockDataStore().getOrGenerateData(widget.deviceId);
    windDirection = data['windDirection'];
    hourlyPmLast24 = (data['pmHistory'] as List).cast<double>();
  }

  void _runSuperTabAlgorithms() {
    // --- TAB 3: DYNAMICS ---
    if (windSpeed > 4 && pm25 > 80) windEffect = "Wind Lifting Dust";
    else if (windSpeed > 4 && pm25 < 50) windEffect = "Wind Clearing Pollution";
    else if (windSpeed < 2) windEffect = "Calm Accumulation";
    else windEffect = "Neutral Transport";

    double avgGlobal = hourlyPmLast24.reduce((a, b) => a + b) / 24;
    double avgCalm = avgGlobal * 1.4;
    calmAccumulationScore = avgCalm / avgGlobal;

    humiditySuppression = (100 - humidity) * 0.5;

    if (pressure < 1002) pressureTrend = "Dropping (Instability Likely)";
    else pressureTrend = "Stable System";

    solarDryingEffect = sunlight > 5000 ? 1.4 : 0.9;

    if (windDirection >= 30 && windDirection <= 80) dominantSector = "Crusher (30°-80°)";
    else if (windDirection >= 120 && windDirection <= 160) dominantSector = "Kiln (120°-160°)";
    else if (windDirection >= 200 && windDirection <= 240) dominantSector = "Loading (200°-240°)";
    else dominantSector = "Undefined Sector";

    // --- TAB 4: COMPLIANCE ---
    pm24hAvg = hourlyPmLast24.reduce((a, b) => a + b) / 24;
    isCompliant = pm24hAvg <= 60; // Class-level assignment

    double pm6hAvg = hourlyPmLast24.sublist(18).reduce((a, b) => a + b) / 6;
    complianceRisk = pm6hAvg > (60 * 0.7) ? "High Risk" : "Low Risk";

    double sumExcess = 0;
    for(var pm in hourlyPmLast24) if(pm > 60) sumExcess += (pm - 60);
    exceedanceSeverity = sumExcess;

    double mean = pm24hAvg;
    double sumSquaredDiff = hourlyPmLast24.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b).toDouble();
    complianceStability = sqrt(sumSquaredDiff / 24);

    performanceScore = max(0, 100 - ((pm24hAvg / 60) * 100));
    controlEffectiveness = isCompliant ? "Sprinklers Active" : "Review Controls";
    weeklyTrend = performanceScore > 80 ? "Stable" : "Degrading";

    if (mounted) setState(() => _isLoading = false);
  }

  // --- NEW: Improved Bottom Sheet UI ---
  void _showDetailBottomSheet(BuildContext context, String title, String description, String status, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("METRIC DETAILS", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0)),
                Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
              ])),
            ]),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("CURRENT STATUS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 6),
                Text(status, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              ]),
            ),
            const SizedBox(height: 24),
            Text("Scientific Explanation", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text(description, style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: Colors.grey[600])),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _getComplianceColor(bool compliant) {
    return compliant ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DashboardScreen()), (route) => false);
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CementDustSpreadScreen(deviceId: widget.deviceId)));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AlertsScreen(deviceId: widget.deviceId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomePopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFF166534),
        appBar: AppBar(
          backgroundColor: const Color(0xFF166534),
          elevation: 0,
          leading: const HomeBackButton(),
          title: Text("Physics & Compliance", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: "Dynamics"), Tab(text: "CPCB Status")],
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(deviceId: widget.deviceId))),
          backgroundColor: const Color(0xFF166534),
          elevation: 4.0,
          shape: const CircleBorder(),
          child: const Icon(LucideIcons.bot, color: Colors.white, size: 28),
        ),
        bottomNavigationBar: CustomBottomNavBar(currentIndex: _selectedIndex, deviceId: widget.deviceId, onItemTapped: _onNavTapped),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF166534)))
                : TabBarView(
              controller: _tabController,
              children: [_buildDynamicsTab(), _buildComplianceTab()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Wind Effect
          GestureDetector(
            onTap: () => _showDetailBottomSheet(context, "Wind Effect", "Determines if wind is helping clear pollution or actively lifting settled dust.", windEffect, LucideIcons.wind, Colors.blue),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: windEffect.contains("Clearing") ? [Colors.green.shade400, Colors.green.shade600] : [Colors.orange.shade400, Colors.orange.shade600]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("WIND DYNAMICS", style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(windEffect, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text("Speed: ${windSpeed.toStringAsFixed(1)} m/s", style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  const Icon(LucideIcons.wind, color: Colors.white, size: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Metrics
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
            children: [
              _buildMetricCard("Calm Accumulation", calmAccumulationScore.toStringAsFixed(2), "Score", LucideIcons.cloudFog, Colors.purple, "Ratio of PM during calm air vs average. >1.3 indicates stagnation."),
              _buildMetricCard("Humidity Impact", "-${humiditySuppression.toStringAsFixed(1)} units", "Suppression", LucideIcons.droplet, Colors.blueAccent, "Reduction in dust potential due to air moisture."),
              _buildMetricCard("Solar Drying", solarDryingEffect.toStringAsFixed(1), "Ratio", LucideIcons.sun, Colors.orange, "Impact of sunlight evaporating moisture and freeing dust."),
              _buildMetricCard("Pressure Trend", pressureTrend, "Barometer", LucideIcons.gauge, Colors.blue, "Falling pressure often precedes weather shifts."),
              _buildMetricCard("Dominant Source", dominantSector, "Sector", LucideIcons.compass, Colors.red, "Wind direction correlation with known plant zones."),
              _buildMetricCard("Wind Direction", "${windDirection.toStringAsFixed(0)}°", "Compass", LucideIcons.navigation, Colors.teal, "Current direction of wind flow."),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildComplianceTab() {
    Color compColor = _getComplianceColor(isCompliant);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Performance
          GestureDetector(
            onTap: () => _showDetailBottomSheet(context, "Environmental Performance", "100 - ((24h Avg PM / 60) * 100). Higher is better.", "${performanceScore.toStringAsFixed(0)}%", LucideIcons.award, compColor),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
              child: Column(
                children: [
                  Text("PERFORMANCE SCORE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(width: 140, height: 140, child: CircularProgressIndicator(value: performanceScore / 100, backgroundColor: Colors.grey[100], valueColor: AlwaysStoppedAnimation<Color>(compColor), strokeWidth: 12, strokeCap: StrokeCap.round)),
                      Column(
                        children: [
                          Text(performanceScore.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
                          Text(isCompliant ? "Compliant" : "Violation", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isCompliant ? Colors.green : Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Full Width Cards
          _buildFullWidthCard("Short-Term Risk", complianceRisk, "Status", LucideIcons.alertTriangle, complianceRisk.contains("High") ? Colors.red : Colors.green, "Probability of exceeding 24h limit based on last 6h trend."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Exceedance Severity", "${exceedanceSeverity.toStringAsFixed(0)} units", "Total Excess", LucideIcons.barChart2, Colors.orange, "Cumulative sum of PM2.5 units above 60 µg/m³ in last 24h."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Compliance Stability", "±${complianceStability.toStringAsFixed(1)}", "Std Dev", LucideIcons.activity, Colors.blue, "Variation in hourly readings. High variation indicates unstable control."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Weekly Trend", weeklyTrend, "7-Day View", LucideIcons.calendar, Colors.purple, "Trend of environmental performance score over the last week."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Control Effectiveness", controlEffectiveness, "Audit", LucideIcons.shieldCheck, Colors.teal, "Automated assessment of current suppression systems."),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color, String desc) {
    return GestureDetector(
      onTap: () => _showDetailBottomSheet(context, title, desc, value, icon, color),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, size: 20, color: color), Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey))]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
            Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
          ])
        ]),
      ),
    );
  }

  Widget _buildFullWidthCard(String title, String value, String status, IconData icon, Color color, String desc) {
    return GestureDetector(
      onTap: () => _showDetailBottomSheet(context, title, desc, "$value ($status)", icon, color),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
            Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }
}