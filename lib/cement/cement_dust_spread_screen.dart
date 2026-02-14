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
import 'cement_emission_screen.dart';
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

class CementDustSpreadScreen extends StatefulWidget {
  final String deviceId;

  const CementDustSpreadScreen({
    super.key,
    this.deviceId = "",
  });

  @override
  State<CementDustSpreadScreen> createState() => _CementDustSpreadScreenState();
}

class _CementDustSpreadScreenState extends State<CementDustSpreadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _selectedIndex = 1;
  final String _baseUrl = "https://gridsphere.in/station/api";

  String overallRisk = "Low";
  double overallRiskValue = 0.0;
  bool _isLoading = true;

  double windSpeed = 0.0;
  double pm25 = 0.0;
  double pm10 = 0.0;

  final List<String> _dustCategories = [
    "Fugitive Dust",
    "Crusher Area Dust",
    "Kiln Discharge Dust",
    "Loading/Unloading Dust",
    "Road Transport Dust",
  ];
  Map<String, dynamic> _dustRisks = {};

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
          pm25 = double.tryParse(reading['pm25']?.toString() ?? "0") ??
              (35 + Random().nextDouble() * 80);
          pm10 = double.tryParse(reading['pm10']?.toString() ?? "0") ??
              (50 + Random().nextDouble() * 120);
          _calculateDustRisks();
        } else {
          _generateMockData();
        }
      } else {
        _generateMockData();
      }
    } catch (e) {
      debugPrint("Error fetching dust spread data: $e");
      _generateMockData();
    }
  }

  void _generateMockData() {
    if (!mounted) return;
    final random = Random();
    windSpeed = 5.0 + random.nextDouble() * 20;
    pm25 = 30 + random.nextDouble() * 100;
    pm10 = 60 + random.nextDouble() * 150;
    _calculateDustRisks();
  }

  void _calculateDustRisks() {
    if (!mounted) return;

    double windFactor = min(windSpeed / 25.0, 1.0);
    double pmFactor = min((pm25 + pm10) / 300.0, 1.0);

    double fugitiveRisk = min((windFactor * 60 + pmFactor * 40), 100);
    double crusherRisk = min((windFactor * 40 + pmFactor * 60), 100);
    double kilnRisk = min((windFactor * 50 + pmFactor * 50), 100);
    double loadingRisk = min((windFactor * 70 + pmFactor * 30), 100);
    double roadRisk = min((windFactor * 55 + pmFactor * 45), 100);

    setState(() {
      _dustRisks = {
        "Fugitive Dust": {
          'value': fugitiveRisk.round(),
          'status': _getRiskLabel(fugitiveRisk)
        },
        "Crusher Area Dust": {
          'value': crusherRisk.round(),
          'status': _getRiskLabel(crusherRisk)
        },
        "Kiln Discharge Dust": {
          'value': kilnRisk.round(),
          'status': _getRiskLabel(kilnRisk)
        },
        "Loading/Unloading Dust": {
          'value': loadingRisk.round(),
          'status': _getRiskLabel(loadingRisk)
        },
        "Road Transport Dust": {
          'value': roadRisk.round(),
          'status': _getRiskLabel(roadRisk)
        },
      };

      List<double> allRisks =
          _dustRisks.values.map((e) => (e['value'] as num).toDouble()).toList();
      overallRiskValue = allRisks.reduce(max);
      overallRisk = _getRiskLabel(overallRiskValue);
      _isLoading = false;
    });
  }

  String _getRiskLabel(double chance) {
    if (chance < 30) return "Low";
    if (chance < 70) return "Medium";
    return "High";
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
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
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CementEmissionScreen(
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
            "Dust Spread Risk",
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
                  Tab(text: "Risk Index"),
                  Tab(text: "PM Levels"),
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
                      _buildRiskIndexContent(),
                      _buildPMLevelsContent(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskIndexContent() {
    Color riskColor = _getRiskColor(overallRisk);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildSummaryCard("Dust Spread Risk", overallRisk, overallRiskValue,
              riskColor, LucideIcons.wind),
          const SizedBox(height: 20),
          _buildDetailList(_dustCategories, _dustRisks),
          const SizedBox(height: 24),
          _buildInsightCard(
              "Wind speed of ${windSpeed.toStringAsFixed(1)} km/h detected. ${overallRisk == "High" ? "High risk of dust dispersion from plant operations. Consider activating dust suppression systems." : overallRisk == "Medium" ? "Moderate dust spread risk. Monitor crusher and kiln areas closely." : "Low dust spread conditions. Normal operations can continue."}"),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPMLevelsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "Particulate Matter Levels",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          _buildPMCard("PM 2.5", pm25, 60, "\u00b5g/m\u00b3", LucideIcons.cloud,
              "Fine particles that can penetrate deep into lungs"),
          const SizedBox(height: 16),
          _buildPMCard(
              "PM 10",
              pm10,
              100,
              "\u00b5g/m\u00b3",
              LucideIcons.cloudFog,
              "Coarse particles from crushing and grinding operations"),
          const SizedBox(height: 16),
          _buildPMCard("Wind Speed", windSpeed, 25, "km/h", LucideIcons.wind,
              "Higher wind speeds increase dust dispersion radius"),
          const SizedBox(height: 24),
          _buildStatusBanner(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPMCard(String title, double value, double maxVal, String unit,
      IconData icon, String description) {
    double ratio = min(value / maxVal, 1.0);
    String status = ratio < 0.5
        ? "Good"
        : ratio < 0.8
            ? "Moderate"
            : "Poor";
    Color statusColor = ratio < 0.5
        ? const Color(0xFF22C55E)
        : ratio < 0.8
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937))),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(status,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827))),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[500])),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    bool isGood = pm25 < 60 && pm10 < 100 && windSpeed < 15;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGood ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isGood ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          Icon(isGood ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
              color: isGood ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isGood
                  ? "PM levels within acceptable limits. Dust suppression systems operating normally."
                  : "Elevated particulate levels detected. Review dust suppression and containment measures.",
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isGood
                      ? const Color(0xFF15803D)
                      : const Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String risk, double chance, Color color, IconData icon) {
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
                  Text("OVERALL RISK",
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
                  value: chance / 100,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${chance.toStringAsFixed(0)}%",
                      style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937))),
                  Text("Risk Level",
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
            child: Text("$risk Risk",
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList(List<String> names, Map<String, dynamic> risks) {
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
            var r = risks[name] ?? {'value': 0, 'status': "Low"};
            double val = (r['value'] as num).toDouble();
            Color c = _getRiskColor(r['status']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF374151))),
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
