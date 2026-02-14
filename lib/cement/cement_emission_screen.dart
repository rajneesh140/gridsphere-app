import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../screens/chat_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../session_manager/session_manager.dart';
import 'cement_dust_spread_screen.dart';
import '../widgets/home_back_button.dart';
import '../widgets/home_pop_scope.dart'; // Import HomePopScope

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

class CementEmissionScreen extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic>? sensorData;

  const CementEmissionScreen({
    super.key,
    this.deviceId = "",
    this.sensorData,
  });

  @override
  State<CementEmissionScreen> createState() => _CementEmissionScreenState();
}

class _CementEmissionScreenState extends State<CementEmissionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _selectedIndex = 3;
  final String _baseUrl = "https://gridsphere.in/station/api";

  String overallImpact = "Low";
  double overallScore = 0.0;
  bool _isLoading = true;

  double windSpeed = 0.0;
  double pressure = 0.0;
  double aqi = 0.0;

  final List<String> _emissionCategories = [
    "Stack Emission Dispersion",
    "Ground Level Concentration",
    "Thermal Plume Rise",
    "Atmospheric Stability",
  ];
  Map<String, dynamic> _emissionScores = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataAndCalculate();
  }

  Future<void> _fetchDataAndCalculate() async {
    if (widget.deviceId.isEmpty || widget.deviceId.contains("Demo")) {
      _generateMockData();
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
        if (jsonResponse is List) {
          readings = jsonResponse;
        } else if (jsonResponse['data'] is List) {
          readings = jsonResponse['data'];
        }

        if (readings.isNotEmpty) {
          final reading = readings[0];
          windSpeed = double.tryParse(reading['wind_speed'].toString()) ?? 0.0;
          pressure = double.tryParse(reading['pressure'].toString()) ?? 1013.0;
          aqi = double.tryParse(reading['aqi']?.toString() ?? "0") ??
              (50 + Random().nextDouble() * 150);
          _calculateEmissionScores();
        } else {
          _generateMockData();
        }
      } else {
        _generateMockData();
      }
    } catch (e) {
      debugPrint("Error fetching emission data: $e");
      _generateMockData();
    }
  }

  void _generateMockData() {
    if (!mounted) return;
    final random = Random();
    windSpeed = 5.0 + random.nextDouble() * 20;
    pressure = 1000 + random.nextDouble() * 30;
    aqi = 50 + random.nextDouble() * 150;
    _calculateEmissionScores();
  }

  void _calculateEmissionScores() {
    if (!mounted) return;

    double windFactor = 1.0 - min(windSpeed / 25.0, 1.0);
    double aqiFactor = min(aqi / 200.0, 1.0);
    double pressureFactor = pressure < 1010
        ? 0.7
        : pressure < 1020
            ? 0.4
            : 0.2;

    double stackDispersion = min(
        (windFactor * 40 + aqiFactor * 40 + pressureFactor * 20) * 1.2, 100);
    double groundConc = min(
        (windFactor * 50 + aqiFactor * 30 + pressureFactor * 20) * 1.1, 100);
    double plumeRise = min(
        (windFactor * 30 + aqiFactor * 20 + pressureFactor * 50) * 1.0, 100);
    double atmoStability = min(
        (windFactor * 35 + aqiFactor * 35 + pressureFactor * 30) * 1.15, 100);

    setState(() {
      _emissionScores = {
        "Stack Emission Dispersion": {
          'value': stackDispersion.round(),
          'status': _getImpactLabel(stackDispersion)
        },
        "Ground Level Concentration": {
          'value': groundConc.round(),
          'status': _getImpactLabel(groundConc)
        },
        "Thermal Plume Rise": {
          'value': plumeRise.round(),
          'status': _getImpactLabel(plumeRise)
        },
        "Atmospheric Stability": {
          'value': atmoStability.round(),
          'status': _getImpactLabel(atmoStability)
        },
      };

      List<double> allScores = _emissionScores.values
          .map((e) => (e['value'] as num).toDouble())
          .toList();
      overallScore = allScores.reduce(max);
      overallImpact = _getImpactLabel(overallScore);
      _isLoading = false;
    });
  }

  String _getImpactLabel(double score) {
    if (score < 30) return "Low";
    if (score < 70) return "Medium";
    return "High";
  }

  Color _getImpactColor(String impact) {
    switch (impact) {
      case "Low":
        return const Color(0xFF22C55E);
      case "Medium":
        return const Color(0xFFF59E0B);
      case "High":
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  void _onNavTapped(int index) {
    if (index == 2 || index == _selectedIndex) return;

    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CementDustSpreadScreen(
                  deviceId: widget.deviceId,
                )),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AlertsScreen(
                  deviceId: widget.deviceId,
                )),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use HomePopScope to wrap Scaffold
    return HomePopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFF166534),
        appBar: AppBar(
          backgroundColor: const Color(0xFF166534),
          elevation: 0,
          leading: const HomeBackButton(),
          title: Text(
            "Emission Impact",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
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
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 16),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Impact Score"),
                  Tab(text: "Parameters"),
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
              MaterialPageRoute(
                  builder: (context) => ChatScreen(deviceId: widget.deviceId)),
            );
          },
          backgroundColor: const Color(0xFF166534),
          elevation: 4.0,
          shape: const CircleBorder(),
          child: const Icon(LucideIcons.bot, color: Colors.white, size: 28),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          deviceId: widget.deviceId,
          onItemTapped: _onNavTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.wind), label: "Dust Risk"),
            BottomNavigationBarItem(icon: SizedBox(height: 24), label: ""),
            BottomNavigationBarItem(
                icon: Icon(LucideIcons.activity), label: "Emission"),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_none), label: "Alerts"),
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF166534)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImpactScoreContent(),
                      _buildParametersContent(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImpactScoreContent() {
    Color impactColor = _getImpactColor(overallImpact);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildSummaryCard("Emission Impact", overallImpact, overallScore,
              impactColor, LucideIcons.activity),
          const SizedBox(height: 20),
          _buildDetailList(_emissionCategories, _emissionScores),
          const SizedBox(height: 24),
          _buildInsightCard(
              "Current AQI: ${aqi.toStringAsFixed(0)}. ${overallImpact == "High" ? "Stack emissions are significantly impacting surrounding areas. Review emission controls and consider reducing kiln operations." : overallImpact == "Medium" ? "Moderate emission impact detected. Ensure scrubbers and filters are operating at full capacity." : "Emission levels are within acceptable limits. Continue standard monitoring."}"),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildParametersContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "Emission Parameters",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildSimpleCard("Wind Speed",
                  "${windSpeed.toStringAsFixed(1)} km/h", LucideIcons.wind),
              _buildSimpleCard(
                  "AQI", aqi.toStringAsFixed(0), LucideIcons.activity),
              _buildSimpleCard("Pressure", "${pressure.toStringAsFixed(1)} hPa",
                  LucideIcons.gauge),
              _buildSimpleCard(
                  "NOx Level",
                  "${(aqi * 0.3).toStringAsFixed(1)} ppb",
                  LucideIcons.cloudFog),
              _buildSimpleCard("SO2 Level",
                  "${(aqi * 0.15).toStringAsFixed(1)} ppb", LucideIcons.cloud),
              _buildSimpleCard(
                  "CO Level",
                  "${(aqi * 0.25).toStringAsFixed(1)} ppm",
                  LucideIcons.cloudDrizzle),
              _buildSimpleCard(
                  "Stack Temp", "185 \u00b0C", LucideIcons.thermometer),
              _buildSimpleCard("Opacity", "18 %", LucideIcons.eye),
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
                    fontSize: 13,
                    color: Colors.grey[700],
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

  Widget _buildSummaryCard(
      String label, String impact, double score, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("OVERALL IMPACT",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937))),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${score.toStringAsFixed(0)}%",
                      style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937))),
                  Text("Impact Score",
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20)),
            child: Text("$impact Impact",
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList(List<String> names, Map<String, dynamic> scores) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Detailed Breakdown",
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937))),
          const SizedBox(height: 16),
          ...names.map((name) {
            var r = scores[name] ?? {'value': 0, 'status': "Low"};
            double val = (r['value'] as num).toDouble();
            Color c = _getImpactColor(r['status']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(name,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF374151))),
                      ),
                      Text("${val.toStringAsFixed(0)}%",
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: c)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: val / 100,
                        child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(4))),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.bot,
                      size: 20, color: Color(0xFF2563EB))),
              const SizedBox(width: 12),
              Text("AI Analysis",
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E40AF))),
            ],
          ),
          const SizedBox(height: 12),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFF1E3A8A), height: 1.5)),
        ],
      ),
    );
  }
}
