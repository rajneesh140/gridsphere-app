import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../screens/chat_screen.dart';
import '../session_manager/session_manager.dart'; // Import SessionManager
import '../widgets/custom_bottom_nav_bar.dart'; // Import CustomBottomNavBar
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

class ProtectionScreen extends StatefulWidget {
  final String deviceId;

  const ProtectionScreen({
    super.key,
    this.deviceId = "",
  });

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _baseUrl = "https://gridsphere.in/station/api";

  String fungusRisk = "Low";
  double fungusChance = 0.0;
  String pestRisk = "Low";
  double pestChance = 0.0;
  bool _isLoading = true;

  final List<String> _fungiNames = [
    "Apple Scab",
    "Alternaria Blotch",
    "Marssonina Blotch",
    "Powdery Mildew",
    "Cedar-Apple Rust",
    "Black Rot",
    "Bitter Rot"
  ];
  Map<String, dynamic> _fungiRisks = {};

  final List<String> _pestNames = [
    "Codling Moth",
    "Aphids",
    "Apple Maggot",
    "Spider Mites",
    "San Jose Scale"
  ];
  Map<String, dynamic> _pestRisks = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Check session validity before fetching
    final cookie = SessionManager().sessionCookie;
    if (cookie.isNotEmpty) {
      _fetchLiveAndCalculateRisks();
    } else {
      debugPrint(
          "⚠️ No session cookie found in ProtectionScreen. Loading mock data.");
      _generateMockData();
    }
  }

  Future<void> _fetchLiveAndCalculateRisks() async {
    String targetDeviceId = widget.deviceId;
    String sessionCookie = SessionManager().sessionCookie; // Get from Manager

    if (targetDeviceId.isEmpty) {
      await _fetchDefaultDevice(sessionCookie);
      targetDeviceId = _tempDeviceId;
    }

    if (targetDeviceId.isEmpty || targetDeviceId.contains("Demo")) {
      _generateMockData();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/live-data/$targetDeviceId'),
        headers: {
          'Cookie': sessionCookie,
          'User-Agent': 'FlutterApp',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> readings = [];
        if (jsonResponse is List)
          readings = jsonResponse;
        else if (jsonResponse['data'] is List) readings = jsonResponse['data'];

        if (readings.isNotEmpty) {
          final reading = readings[0];
          double temp = double.tryParse(reading['temp'].toString()) ?? 0.0;
          double humidity =
              double.tryParse(reading['humidity'].toString()) ?? 0.0;
          double wetnessHours =
              await _calculateWetnessDuration(targetDeviceId, sessionCookie);
          _calculateRisks(temp, wetnessHours, humidity);
        } else {
          _generateMockData();
        }
      } else {
        _generateMockData();
      }
    } catch (e) {
      debugPrint("Error fetching live protection data: $e");
      _generateMockData();
    }
  }

  Future<double> _calculateWetnessDuration(String id, String cookie) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/devices/$id/history?range=daily'),
        headers: {
          'Cookie': cookie,
          'User-Agent': 'FlutterApp',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        List<dynamic> list = [];
        if (jsonResponse is List)
          list = jsonResponse;
        else if (jsonResponse['data'] is List) list = jsonResponse['data'];

        int wetCount = 0;
        for (var r in list) {
          String status = r['leafwetness']?.toString().toLowerCase() ?? "dry";
          if (status == "wet" ||
              status == "1" ||
              (double.tryParse(status) ?? 0) > 0) {
            wetCount++;
          }
        }
        return wetCount.toDouble();
      }
    } catch (e) {
      return 0.0;
    }
    return 0.0;
  }

  String _tempDeviceId = "";
  Future<void> _fetchDefaultDevice(String cookie) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getDevices'),
        headers: {'Cookie': cookie, 'User-Agent': 'FlutterApp'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _tempDeviceId = data[0]['d_id'].toString();
        } else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
          _tempDeviceId = data['data'][0]['d_id'].toString();
        }
      }
    } catch (_) {}
  }

  void _calculateRisks(double temp, double wetnessHours, double humidity) {
    Map<String, dynamic> scab = _calculateAppleScab(temp, wetnessHours);
    Map<String, dynamic> alternaria = _calculateAlternaria(temp, wetnessHours);
    Map<String, dynamic> marssonina = _calculateMarssonina(temp, wetnessHours);
    Map<String, dynamic> mildew = _calculatePowderyMildew(temp, humidity);
    Map<String, dynamic> cedar = _calculateCedarRust(temp, wetnessHours);
    Map<String, dynamic> blackRot = _calculateBlackRot(temp, wetnessHours);
    Map<String, dynamic> bitterRot = _calculateBitterRot(temp, wetnessHours);

    double degreeDays = (temp > 10) ? (temp - 10) * 15 : 50;

    Map<String, dynamic> codlingMoth = _getCodlingMothRisk(degreeDays);
    Map<String, dynamic> aphids = _getAphidRisk(temp, humidity);
    Map<String, dynamic> appleMaggot = _getAppleMaggotRisk(degreeDays);
    Map<String, dynamic> spiderMites = _getSpiderMiteRisk(temp, humidity);
    Map<String, dynamic> sanJoseScale = _getSanJoseScaleRisk(degreeDays);

    setState(() {
      _fungiRisks = {
        "Apple Scab": scab,
        "Alternaria Blotch": alternaria,
        "Marssonina Blotch": marssonina,
        "Powdery Mildew": mildew,
        "Cedar-Apple Rust": cedar,
        "Black Rot": blackRot,
        "Bitter Rot": bitterRot,
      };

      List<double> allFungusRisks = [
        (scab['value'] as num).toDouble(),
        (alternaria['value'] as num).toDouble(),
        (marssonina['value'] as num).toDouble(),
        (mildew['value'] as num).toDouble(),
        (cedar['value'] as num).toDouble(),
        (blackRot['value'] as num).toDouble(),
        (bitterRot['value'] as num).toDouble(),
      ];

      fungusChance = allFungusRisks.reduce(max);
      fungusRisk = _getRiskLabel(fungusChance);

      _pestRisks = {
        "Codling Moth": codlingMoth,
        "Aphids": aphids,
        "Apple Maggot": appleMaggot,
        "Spider Mites": spiderMites,
        "San Jose Scale": sanJoseScale,
      };

      List<double> allPestRisks = [
        (codlingMoth['value'] as num).toDouble(),
        (aphids['value'] as num).toDouble(),
        (appleMaggot['value'] as num).toDouble(),
        (spiderMites['value'] as num).toDouble(),
        (sanJoseScale['value'] as num).toDouble(),
      ];

      pestChance = allPestRisks.reduce(max);
      pestRisk = _getRiskLabel(pestChance);

      _isLoading = false;
    });
  }

  void _generateMockData() {
    final random = Random();
    double temp = 15.0 + random.nextDouble() * 15;
    double wetnessHours = random.nextDouble() * 24;
    double humidity = 50 + random.nextDouble() * 50;
    _calculateRisks(temp, wetnessHours, humidity);
  }

  Map<String, dynamic> _calculateAppleScab(double temp, double wetnessHours) {
    if (temp < 6) return {'value': 0, 'status': "Low"};
    double? requiredHours;
    if (temp >= 18 && temp <= 24) {
      requiredHours = 9;
    } else if (temp >= 17 && temp < 18) {
      requiredHours = 10;
    } else if (temp >= 16 && temp < 17) {
      requiredHours = 11;
    } else if (temp >= 15 && temp < 16) {
      requiredHours = 12;
    } else if (temp >= 13 && temp <= 14) {
      requiredHours = 14;
    } else if (temp >= 12 && temp < 13) {
      requiredHours = 15;
    } else if (temp >= 10 && temp <= 11) {
      requiredHours = 20;
    }
    if (requiredHours == null) return {'value': 0, 'status': "Low"};
    double risk = min((wetnessHours / requiredHours) * 100, 100);
    String status = "Low";
    if (risk >= 70) {
      status = "High";
    } else if (risk >= 40) {
      status = "Medium";
    }
    return {'value': risk.round(), 'status': status};
  }

  Map<String, dynamic> _calculateAlternaria(double temp, double wetnessHours) {
    if (temp >= 25 && temp <= 30 && wetnessHours >= 5.5)
      return {'value': 80, 'status': "High"};
    if (temp >= 20 && temp <= 32 && wetnessHours >= 4)
      return {'value': 50, 'status': "Medium"};
    return {'value': 0, 'status': "Low"};
  }

  Map<String, dynamic> _calculateMarssonina(double temp, double wetnessHours) {
    if (temp >= 20 && temp <= 25 && wetnessHours >= 24)
      return {'value': 90, 'status': "High"};
    if (temp >= 16 && temp <= 28 && wetnessHours >= 10)
      return {'value': 60, 'status': "Medium"};
    return {'value': 0, 'status': "Low"};
  }

  Map<String, dynamic> _calculatePowderyMildew(double temp, double humidity) {
    if (temp < 10 || temp > 25 || humidity < 70)
      return {'value': 0, 'status': "Low"};
    bool optimal = (temp >= 19 && temp <= 22 && humidity > 75);
    int risk = optimal ? 90 : 60;
    return {'value': risk, 'status': risk >= 70 ? "High" : "Medium"};
  }

  Map<String, dynamic> _calculateCedarRust(double temp, double wetnessHours) {
    if (temp >= 13 && temp <= 24 && wetnessHours >= 4)
      return {'value': 75, 'status': "High"};
    if (temp >= 10 && temp <= 26 && wetnessHours >= 2)
      return {'value': 50, 'status': "Medium"};
    return {'value': 0, 'status': "Low"};
  }

  Map<String, dynamic> _calculateBlackRot(double temp, double wetnessHours) {
    if (temp < 20 || temp > 35 || wetnessHours < 4)
      return {'value': 0, 'status': "Low"};
    bool optimal = (temp >= 26 && temp <= 32 && wetnessHours >= 6);
    int risk = optimal ? 85 : 60;
    return {'value': risk, 'status': risk >= 70 ? "High" : "Medium"};
  }

  Map<String, dynamic> _calculateBitterRot(double temp, double wetnessHours) {
    if (temp >= 26 && temp <= 32 && wetnessHours >= 5)
      return {'value': 80, 'status': "High"};
    if (temp >= 20 && temp <= 35 && wetnessHours >= 3)
      return {'value': 50, 'status': "Medium"};
    return {'value': 0, 'status': "Low"};
  }

  Map<String, dynamic> _getCodlingMothRisk(double degreeDays) {
    Map<String, dynamic> risk = {'value': 0, 'status': "Low"};
    if (degreeDays > 50 && degreeDays <= 250)
      risk = {'value': 40, 'status': "Medium"};
    else if (degreeDays > 250) risk = {'value': 85, 'status': "High"};
    return risk;
  }

  Map<String, dynamic> _getAphidRisk(double temp, double humidity) {
    Map<String, dynamic> risk = {'value': 10, 'status': "Low"};
    if (temp > 18 && temp < 25 && humidity < 70)
      risk = {'value': 90, 'status': "High"};
    else if (temp > 15 && temp < 28) risk = {'value': 50, 'status': "Medium"};
    return risk;
  }

  Map<String, dynamic> _getAppleMaggotRisk(double degreeDays) {
    Map<String, dynamic> risk = {'value': 0, 'status': "Low"};
    if (degreeDays > 900)
      risk = {'value': 80, 'status': "High"};
    else if (degreeDays > 700) risk = {'value': 40, 'status': "Medium"};
    return risk;
  }

  Map<String, dynamic> _getSpiderMiteRisk(double temp, double humidity) {
    Map<String, dynamic> risk = {'value': 10, 'status': "Low"};
    if (temp > 29 && humidity < 60)
      risk = {'value': 95, 'status': "High"};
    else if (temp > 25 && humidity < 70)
      risk = {'value': 60, 'status': "Medium"};
    return risk;
  }

  Map<String, dynamic> _getSanJoseScaleRisk(double degreeDays) {
    Map<String, dynamic> risk = {'value': 0, 'status': "Low"};
    if (degreeDays > 400 && degreeDays < 600)
      risk = {'value': 90, 'status': "High"};
    else if (degreeDays > 250) risk = {'value': 30, 'status': "Medium"};
    return risk;
  }

  String _getRiskLabel(double chance) {
    if (chance < 30) return "Low";
    if (chance < 70) return "Medium";
    return "High";
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case "Low":
      case "No Risk":
        return const Color(0xFF22C55E);
      case "Medium":
        return const Color(0xFFF59E0B);
      case "High":
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
    // --- UPDATED: Use HomePopScope Wrapper ---
    return HomePopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFF166534),
        appBar: AppBar(
          backgroundColor: const Color(0xFF166534),
          elevation: 0,
          leading:
              const HomeBackButton(), // Also use HomeBackButton for UI back arrow
          title: Text(
            "Field Protection",
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
                  Tab(text: "Fungal Risk"),
                  Tab(text: "Pest Activity"),
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

        // --- Custom Bottom Navigation Bar ---
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: 1, // Protection is index 1
          deviceId: widget.deviceId,
          // Pass session manager coordinates for consistent navigation context
          sensorData: null,
          latitude: SessionManager().latitude,
          longitude: SessionManager().longitude,
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
                      _buildFungusContent(),
                      _buildPestContent(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ... (Fungus/Pest content widgets remain unchanged)
  Widget _buildFungusContent() {
    Color riskColor = _getRiskColor(fungusRisk);
    Color bgColor = riskColor.withOpacity(0.05);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
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
                        Text(
                          "OVERALL RISK",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Fungal Infection",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(LucideIcons.sprout, color: riskColor, size: 28),
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
                        value: fungusChance / 100,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${fungusChance.toStringAsFixed(0)}%",
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          "Probability",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$fungusRisk Risk",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Specific Disease Risks",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                ..._fungiNames.map((name) {
                  var riskObj = _fungiRisks[name];
                  double val = 0;
                  String status = "Low";

                  if (riskObj is Map) {
                    val = (riskObj['value'] as num).toDouble();
                    status = riskObj['status'];
                  }

                  Color c = _getRiskColor(status);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            Text(
                              "${val.toStringAsFixed(0)}%",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: c,
                              ),
                            ),
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
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: val / 100,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.bot,
                          size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "AI Assistant Insight",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "High humidity levels (>90%) observed for 12+ hours. Conditions are favorable for Apple Scab spore germination.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E3A8A),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPestContent() {
    Color riskColor = _getRiskColor(pestRisk);
    Color bgColor = riskColor.withOpacity(0.05);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
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
                        Text(
                          "OVERALL ACTIVITY",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Pest Activity",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(LucideIcons.bug, color: riskColor, size: 28),
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
                        value: pestChance / 100,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${pestChance.toStringAsFixed(0)}%",
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          "Probability",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$pestRisk Activity",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Specific Pest Activity",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                ..._pestNames.map((name) {
                  var riskObj = _pestRisks[name];
                  double val = 0;
                  String status = "Low";

                  if (riskObj is Map) {
                    val = (riskObj['value'] as num).toDouble();
                    status = riskObj['status'];
                  }

                  Color c = _getRiskColor(status);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            Text(
                              "${val.toStringAsFixed(0)}%",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: c,
                              ),
                            ),
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
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: val / 100,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.bot,
                          size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "AI Assistant Insight",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Warm temperatures (24°C) favor rapid aphid reproduction. Inspect undersides of leaves in Zone B.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E3A8A),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
