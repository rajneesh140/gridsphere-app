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
import 'cement_emission_screen.dart';
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

class CementDustSpreadScreen extends StatefulWidget {
  final String deviceId;

  const CementDustSpreadScreen({super.key, this.deviceId = ""});

  @override
  State<CementDustSpreadScreen> createState() => _CementDustSpreadScreenState();
}

class _CementDustSpreadScreenState extends State<CementDustSpreadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _selectedIndex = 1;
  final String _baseUrl = "https://gridsphere.in/station/api";

  bool _isLoading = true;

  // Data Variables
  double pm25 = 0.0;
  double tvoc = 0.0;
  double windSpeed = 0.0;
  double memsCurrent = 0.0;
  double humidity = 0.0;
  double sunlight = 0.0;

  // Calculated Metrics
  double airScore = 0.0;
  String airRiskCategory = "Clean Air";
  double exposureLoad = 0.0;
  String pollutionMomentum = "Stable";
  String aqConfidence = "High";
  String sensorHealth = "Optimal";
  double operationalContribution = 0.0;
  double passiveContribution = 0.0;
  double dustGenEfficiency = 0.0;
  String rainRecoveryTime = "--";
  String drySurfaceRisk = "Low";
  String activityWindMatrix = "Safe";
  int spikeFrequency = 0;

  List<double> pmHistory24h = [];
  List<double> memsHistory24h = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataAndCalculate();
  }

  Future<void> _fetchDataAndCalculate() async {
    // 1. Safety Check: Use Mock Data for Demo/Empty IDs
    if (widget.deviceId.isEmpty || widget.deviceId.contains("Demo")) {
      _loadPersistentData();
      return;
    }

    try {
      // 2. Define Headers (Reuse for both calls)
      final headers = {
        'Cookie': SessionManager().sessionCookie, // vital for auth
        'User-Agent': 'FlutterApp',
        'Accept': 'application/json',
      };

      // 3. Parallel API Calls: Fetch Live AND History together
      final results = await Future.wait([
        // Call 1: Get latest reading
        http.get(Uri.parse('$_baseUrl/live-data/${widget.deviceId}'), headers: headers),
        // Call 2: Get last 24h history (Daily range)
        http.get(Uri.parse('$_baseUrl/devices/${widget.deviceId}/history?range=daily'), headers: headers),
      ]);

      final liveResponse = results[0];
      final historyResponse = results[1];

      if (!mounted) return;

      // --- PROCESS LIVE DATA ---
      if (liveResponse.statusCode == 200) {
        final json = jsonDecode(liveResponse.body);
        // Handle if data is wrapped in 'data' key or direct list
        dynamic data = json['data'] ?? json;
        if (data is List && data.isNotEmpty) data = data[0];

        if (data != null && data is Map) {
          setState(() {
            // Parse Backend Fields (Safety checks for null/strings)
            pm25 = double.tryParse(data['pm25']?.toString() ?? "0") ?? 0.0;

            // ✅ TVOC is in your database, so map it now!
            tvoc = double.tryParse(data['tvoc']?.toString() ?? "0") ?? 0.0;

            windSpeed = double.tryParse(data['wind_speed']?.toString() ?? "0") ?? 0.0;
            humidity = double.tryParse(data['humidity']?.toString() ?? "0") ?? 0.0;
            sunlight = double.tryParse(data['light_intensity']?.toString() ?? "0") ?? 0.0;

            // ⚠️ MEMS/Vibration isn't in your PHP model yet, so we use a mock fallback
            // If you add a 'vibration' column later, change this line:
            memsCurrent = double.tryParse(data['vibration']?.toString() ?? "0") ?? MockDataStore().getOrGenerateData(widget.deviceId)['memsCurrent'];
          });
        }
      }

      // --- PROCESS HISTORICAL DATA ---
      if (historyResponse.statusCode == 200) {
        final json = jsonDecode(historyResponse.body);
        final List<dynamic> historyList = (json['data'] is List) ? json['data'] : [];

        if (historyList.isNotEmpty) {
          setState(() {
            // Map the history list to a List<double> for PM2.5
            pmHistory24h = historyList.map<double>((item) {
              return double.tryParse(item['pm25']?.toString() ?? "0") ?? 0.0;
            }).toList();

            // Handle MEMS history (Mock fallback if missing from DB)
            if (historyList.first.containsKey('vibration')) {
              memsHistory24h = historyList.map<double>((item) {
                return double.tryParse(item['vibration']?.toString() ?? "0") ?? 0.0;
              }).toList();
            } else {
              // Keep existing mock pattern if DB doesn't have vibration history
              memsHistory24h = MockDataStore().getOrGenerateData(widget.deviceId)['memsHistory'];
            }
          });
        }
      }

      // 4. Run algorithms with the new Real Data
      _runAdvancedAlgorithms();

    } catch (e) {
      print("Error fetching backend data: $e");
      // Fallback to mock on error so screen doesn't break
      _loadPersistentData();
    }
  }

  void _loadPersistentData() {
    if (!mounted) return;
    // Get consistent data for this device ID
    final data = MockDataStore().getOrGenerateData(widget.deviceId);

    pm25 = data['pm25'];
    tvoc = data['tvoc'];
    windSpeed = data['windSpeed'];
    humidity = data['humidity'];
    sunlight = data['sunlight'];
    memsCurrent = data['memsCurrent'];
    pmHistory24h = (data['pmHistory'] as List).cast<double>();
    memsHistory24h = (data['memsHistory'] as List).cast<double>();

    _runAdvancedAlgorithms();
  }

  void _fillMissingSensorsWithPersistence() {
    // Even if we have live PM2.5, we might lack TVOC/MEMS.
    // Fetch them from the store so they don't jump around.
    final data = MockDataStore().getOrGenerateData(widget.deviceId);

    tvoc = data['tvoc'];
    memsCurrent = data['memsCurrent'];
    pmHistory24h = (data['pmHistory'] as List).cast<double>();
    memsHistory24h = (data['memsHistory'] as List).cast<double>();
  }

  void _runAdvancedAlgorithms() {
    // 1. Air Quality Score
    double drynessIndex = (100 - humidity) * 0.6 + (sunlight / 10000 * 100) * 0.4;
    double stabilityRisk = (windSpeed < 2) ? 20 : (windSpeed <= 5 ? 10 : 0);
    double pmAdjusted = pm25;
    double vocSeverity = min((tvoc / 600) * 100, 100);

    double rawScore = (0.55 * pmAdjusted) + (0.25 * vocSeverity) + (0.1 * drynessIndex) + (0.1 * stabilityRisk);
    airScore = min(rawScore, 100.0);

    if (airScore <= 25) airRiskCategory = "Clean Air";
    else if (airScore <= 50) airRiskCategory = "Manageable";
    else if (airScore <= 70) airRiskCategory = "Elevated";
    else if (airScore <= 85) airRiskCategory = "High Risk";
    else airRiskCategory = "Severe Condition";

    // Exposure
    exposureLoad = pmHistory24h.fold(0.0, (sum, pm) => sum + (pm * (pm > 60 ? (pm > 100 ? 2.0 : 1.5) : 1.0)));

    // Momentum
    double pm30minAvg = (pmHistory24h.isNotEmpty)
        ? (pmHistory24h.last + pmHistory24h[max(0, pmHistory24h.length - 2)]) / 2
        : pm25;
    double momentum = pm30minAvg == 0 ? 0 : (pm25 - pm30minAvg) / pm30minAvg;

    if (momentum > 0.15) pollutionMomentum = "Rapidly Rising";
    else if (momentum > 0.05) pollutionMomentum = "Slowly Increasing";
    else if (momentum > -0.05) pollutionMomentum = "Stable";
    else pollutionMomentum = "Improving Fast";

    sensorHealth = (pm25 > 0 && humidity > 0) ? "Optimal" : "Check Sensors";

    // 2. Activity Impact
    int totalSpikes = 0;
    int linkedSpikes = 0;
    for (int i = 0; i < pmHistory24h.length; i++) {
      if (pmHistory24h[i] > 60) {
        totalSpikes++;
        if (memsHistory24h[i] > 50) linkedSpikes++;
      }
    }
    operationalContribution = totalSpikes == 0 ? 0 : (linkedSpikes / totalSpikes) * 100;
    passiveContribution = 100 - operationalContribution;
    spikeFrequency = totalSpikes;

    dustGenEfficiency = 85.0 / 40.0;
    rainRecoveryTime = (humidity > 90) ? "Calculating..." : "45 mins";
    drySurfaceRisk = (humidity < 40 && sunlight > 5000 && windSpeed > 4) ? "High Dust Lift Risk" : "Stable Conditions";

    if (memsCurrent > 60 && windSpeed > 5) activityWindMatrix = "Dangerous: Activity + Dispersion";
    else if (memsCurrent > 60) activityWindMatrix = "Localized Activity Spikes";
    else if (windSpeed > 5) activityWindMatrix = "Wind-Driven Resuspension";
    else activityWindMatrix = "Safe Operating Zone";

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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("METRIC DETAILS", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0)),
                      Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.1))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CURRENT STATUS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 6),
                  Text(status, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
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

  Color _getScoreColor(double score) {
    if (score <= 25) return const Color(0xFF22C55E);
    if (score <= 50) return const Color(0xFFF59E0B);
    if (score <= 70) return const Color(0xFFF97316);
    if (score <= 85) return const Color(0xFFEF4444);
    return const Color(0xFF7F1D1D);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DashboardScreen()), (route) => false);
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CementEmissionScreen(deviceId: widget.deviceId)));
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
          title: Text("Air Intelligence", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                tabs: const [Tab(text: "Air IQ"), Tab(text: "Impact")],
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
              children: [_buildAirIQTab(), _buildImpactTab()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAirIQTab() {
    Color scoreColor = _getScoreColor(airScore);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Score Card
          GestureDetector(
            onTap: () => _showDetailBottomSheet(context, "Environmental Score", "A composite score (0-100) combining Pollution (PM/VOC), Weather Trapping (Stability), and Surface Conditions (Dryness).", "$airRiskCategory (Score: ${airScore.toStringAsFixed(0)})", LucideIcons.gauge, scoreColor),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
              child: Column(
                children: [
                  Text("ENVIRONMENTAL SCORE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(width: 140, height: 140, child: CircularProgressIndicator(value: airScore / 100, backgroundColor: Colors.grey[100], valueColor: AlwaysStoppedAnimation<Color>(scoreColor), strokeWidth: 12, strokeCap: StrokeCap.round)),
                      Column(
                        children: [
                          Text(airScore.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
                          Text(airRiskCategory, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Metrics
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
            children: [
              _buildMetricCard("Exposure Load", exposureLoad.toStringAsFixed(0), "Cumulative", LucideIcons.layers, Colors.purple, "Total environmental burden over 24h weighted by severity."),
              _buildMetricCard("Momentum", pollutionMomentum, "Trend", LucideIcons.trendingUp, Colors.blue, "Rate of change in pollution levels vs 30-min average."),
              _buildMetricCard("Confidence", aqConfidence, "Data Quality", LucideIcons.signal, Colors.green, "Reliability of sensor data based on fluctuation variance."),
              _buildMetricCard("Sensor Health", sensorHealth, "System", LucideIcons.stethoscope, Colors.teal, "Operational status of PM and environmental sensors."),
              _buildMetricCard("PM 2.5 Raw", "${pm25.toStringAsFixed(0)} µg/m³", "Real-time", LucideIcons.cloud, Colors.grey, "Direct sensor reading before algorithmic adjustment."),
              _buildMetricCard("TVOC Level", "${tvoc.toStringAsFixed(0)} ppb", "Gas", LucideIcons.flaskConical, Colors.orange, "Total Volatile Organic Compounds concentration."),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildImpactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showDetailBottomSheet(context, "Operational Contribution", "Percentage of pollution spikes linked to detected machinery vibration.", "${operationalContribution.toStringAsFixed(0)}% Plant vs ${passiveContribution.toStringAsFixed(0)}% Passive", LucideIcons.factory, const Color(0xFF166534)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("Operational Contribution", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text("${operationalContribution.toStringAsFixed(0)}%", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: operationalContribution / 100, minHeight: 12, backgroundColor: Colors.orange.shade100, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF166534)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildFullWidthCard("Dust Gen Efficiency", dustGenEfficiency.toStringAsFixed(2), dustGenEfficiency > 1.5 ? "Inefficient" : "Efficient", LucideIcons.settings, dustGenEfficiency > 1.5 ? Colors.red : Colors.green, "Ratio of PM during High Activity vs Low Activity."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Rain Recovery", rainRecoveryTime, "Time to Baseline", LucideIcons.cloudRain, Colors.blue, "Estimated time for dust levels to return to pre-rain baseline."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Dry Surface Risk", drySurfaceRisk, "Forecast", LucideIcons.sun, drySurfaceRisk.contains("High") ? Colors.orange : Colors.blue, "Prediction based on Humidity, Sunlight, and Wind Speed."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Activity-Wind Matrix", activityWindMatrix, "Interaction", LucideIcons.wind, activityWindMatrix.contains("Dangerous") ? Colors.red : Colors.teal, "Cross-analysis of MEMS activity and Wind Speed."),
          const SizedBox(height: 12),
          _buildFullWidthCard("Spike Frequency", "$spikeFrequency / 24h", "Event Count", LucideIcons.activity, Colors.purple, "Number of significant PM spikes recorded in the last 24 hours."),
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