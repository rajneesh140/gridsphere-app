import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'chat_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'chemical_dust_spread_screen.dart';

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

class ChemicalProcessStabilityScreen extends StatefulWidget {
  final String sessionCookie;
  final String deviceId;
  final Map<String, dynamic>? sensorData;

  const ChemicalProcessStabilityScreen({
    super.key,
    required this.sessionCookie,
    this.deviceId = "",
    this.sensorData,
  });

  @override
  State<ChemicalProcessStabilityScreen> createState() =>
      _ChemicalProcessStabilityScreenState();
}

class _ChemicalProcessStabilityScreenState
    extends State<ChemicalProcessStabilityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 3;
  final String _baseUrl = "https://gridsphere.in/station/api";

  String overallStability = "Stable";
  double overallScore = 0.0;
  bool _isLoading = true;

  double temperature = 0.0;
  double humidity = 0.0;
  double pressure = 0.0;

  final List<String> _stabilityCategories = [
    "Reactor Temperature Control",
    "Humidity-Sensitive Materials",
    "Pressure Vessel Integrity",
    "Atmospheric Process Conditions",
  ];
  Map<String, dynamic> _stabilityScores = {};

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
          'Cookie': widget.sessionCookie,
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
          temperature =
              double.tryParse(reading['temp'].toString()) ?? 0.0;
          humidity =
              double.tryParse(reading['humidity'].toString()) ?? 0.0;
          pressure =
              double.tryParse(reading['pressure'].toString()) ?? 1013.0;
          _calculateStabilityScores();
        } else {
          _generateMockData();
        }
      } else {
        _generateMockData();
      }
    } catch (e) {
      debugPrint("Error fetching process stability data: $e");
      _generateMockData();
    }
  }

  void _generateMockData() {
    if (!mounted) return;
    final random = Random();
    temperature = 18.0 + random.nextDouble() * 18;
    humidity = 40 + random.nextDouble() * 50;
    pressure = 1000 + random.nextDouble() * 35;
    _calculateStabilityScores();
  }

  void _calculateStabilityScores() {
    if (!mounted) return;

    // Temperature stability: optimal 20-25°C
    double tempDeviation = (temperature - 22.5).abs();
    double tempScore = max(0, 100 - (tempDeviation * 10));

    // Humidity stability: optimal 40-60%
    double humScore;
    if (humidity >= 40 && humidity <= 60) {
      humScore = 100;
    } else if (humidity < 40) {
      humScore = max(0, 100 - ((40 - humidity) * 2));
    } else {
      humScore = max(0, 100 - ((humidity - 60) * 1.5));
    }

    // Pressure stability: optimal 1013 ± 10 hPa
    double pressDeviation = (pressure - 1013).abs();
    double pressScore = max(0, 100 - (pressDeviation * 3));

    // Combined scores for different process aspects
    double reactorScore = min(
        (tempScore * 0.7 + pressScore * 0.3), 100);
    double materialsScore = min(
        (humScore * 0.7 + tempScore * 0.3), 100);
    double vesselScore = min(
        (pressScore * 0.6 + tempScore * 0.4), 100);
    double atmosphericScore = min(
        (tempScore * 0.4 + humScore * 0.3 + pressScore * 0.3), 100);

    setState(() {
      _stabilityScores = {
        "Reactor Temperature Control": {
          'value': 100 - reactorScore.round(),
          'status': _getStabilityLabel(100 - reactorScore)
        },
        "Humidity-Sensitive Materials": {
          'value': 100 - materialsScore.round(),
          'status': _getStabilityLabel(100 - materialsScore)
        },
        "Pressure Vessel Integrity": {
          'value': 100 - vesselScore.round(),
          'status': _getStabilityLabel(100 - vesselScore)
        },
        "Atmospheric Process Conditions": {
          'value': 100 - atmosphericScore.round(),
          'status': _getStabilityLabel(100 - atmosphericScore)
        },
      };

      List<double> allScores = _stabilityScores.values
          .map((e) => (e['value'] as num).toDouble())
          .toList();
      overallScore = allScores.reduce(max);
      overallStability = _getStabilityLabel(overallScore);
      _isLoading = false;
    });
  }

  String _getStabilityLabel(double score) {
    if (score < 30) return "Stable";
    if (score < 70) return "Moderate";
    return "Unstable";
  }

  Color _getStabilityColor(String stability) {
    switch (stability) {
      case "Stable":
        return const Color(0xFF22C55E);
      case "Moderate":
        return const Color(0xFFF59E0B);
      case "Unstable":
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
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
      backgroundColor: const Color(0xFF166534),
      appBar: AppBar(
        backgroundColor: const Color(0xFF166534),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Process Stability",
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
                Tab(text: "Stability Score"),
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
                builder: (context) => const ChatScreen()),
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
        selectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        onTap: (index) {
          if (index == 2 || index == _selectedIndex) return;

          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      DashboardScreen(sessionCookie: widget.sessionCookie)),
              (route) => false,
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ChemicalDustSpreadScreen(
                        sessionCookie: widget.sessionCookie,
                        deviceId: widget.deviceId,
                      )),
            ).then((_) {
              if (mounted) setState(() => _selectedIndex = 3);
            });
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AlertsScreen(
                        sessionCookie: widget.sessionCookie,
                        deviceId: widget.deviceId,
                      )),
            ).then((_) {
              if (mounted) setState(() => _selectedIndex = 3);
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(LucideIcons.wind), label: "Pollution"),
          BottomNavigationBarItem(icon: SizedBox(height: 24), label: ""),
          BottomNavigationBarItem(
              icon: Icon(LucideIcons.gauge), label: "Stability"),
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(30)),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF166534)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStabilityScoreContent(),
                    _buildParametersContent(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStabilityScoreContent() {
    Color stabilityColor = _getStabilityColor(overallStability);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildSummaryCard("Process Environment", overallStability,
              overallScore, stabilityColor, LucideIcons.gauge),
          const SizedBox(height: 20),
          _buildDetailList(_stabilityCategories, _stabilityScores),
          const SizedBox(height: 24),
          _buildInsightCard(
              "Ambient Temp: ${temperature.toStringAsFixed(1)}°C, Humidity: ${humidity.toStringAsFixed(0)}%. ${overallStability == "Unstable" ? "Unstable ambient conditions detected. Chemical processes may be affected. Consider implementing environmental controls." : overallStability == "Moderate" ? "Moderate environmental stability. Monitor temperature-sensitive reactions and hygroscopic materials." : "Stable ambient conditions. Chemical processes can proceed under normal protocols."}"),
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
            "Environmental Parameters",
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
              _buildSimpleCard("Temperature",
                  "${temperature.toStringAsFixed(1)} °C", LucideIcons.thermometer),
              _buildSimpleCard(
                  "Humidity", "${humidity.toStringAsFixed(0)} %",
                  LucideIcons.droplets),
              _buildSimpleCard("Pressure",
                  "${pressure.toStringAsFixed(1)} hPa", LucideIcons.gauge),
              _buildSimpleCard("Dew Point",
                  "${(temperature - ((100 - humidity) / 5)).toStringAsFixed(1)} °C",
                  LucideIcons.cloudDrizzle),
              _buildSimpleCard("Vapor Pressure",
                  "${(pressure * 0.023).toStringAsFixed(1)} kPa",
                  LucideIcons.cloudFog),
              _buildSimpleCard("Heat Index",
                  "${(temperature + (humidity * 0.1)).toStringAsFixed(1)} °C",
                  LucideIcons.flame),
              _buildSimpleCard("Comfort Level",
                  _getComfortLevel(), LucideIcons.thermometerSun),
              _buildSimpleCard("Process Risk",
                  _getProcessRisk(), LucideIcons.alertTriangle),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _getComfortLevel() {
    if (temperature >= 20 &&
        temperature <= 26 &&
        humidity >= 40 &&
        humidity <= 60) {
      return "Optimal";
    } else if (temperature >= 18 &&
        temperature <= 28 &&
        humidity >= 35 &&
        humidity <= 70) {
      return "Acceptable";
    } else {
      return "Poor";
    }
  }

  String _getProcessRisk() {
    double tempRisk = (temperature - 22.5).abs();
    double humRisk = humidity < 40
        ? (40 - humidity).abs()
        : humidity > 60
            ? (humidity - 60).abs()
            : 0;

    if (tempRisk > 8 || humRisk > 25) return "High";
    if (tempRisk > 4 || humRisk > 15) return "Medium";
    return "Low";
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
                child:
                    Icon(icon, size: 16, color: const Color(0xFF166534)),
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

  Widget _buildSummaryCard(String label, String stability, double score,
      Color color, IconData icon) {
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
                  Text("OVERALL STATUS",
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
                  Text("Deviation",
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20)),
            child: Text(stability,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList(
      List<String> names, Map<String, dynamic> scores) {
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
            var r = scores[name] ?? {'value': 0, 'status': "Stable"};
            double val = (r['value'] as num).toDouble();
            Color c = _getStabilityColor(r['status']);
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
        border:
            Border.all(color: const Color(0xFFBFDBFE).withOpacity(0.5)),
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
                  fontSize: 14,
                  color: const Color(0xFF1E3A8A),
                  height: 1.5)),
        ],
      ),
    );
  }
}
