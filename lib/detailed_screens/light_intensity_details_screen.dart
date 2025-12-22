import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart' hide TextDirection; 

class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class GraphPoint {
  final DateTime time;
  final double value;

  GraphPoint({required this.time, required this.value});
}

class LightIntensityDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? sensorData;
  final String deviceId;
  final String sessionCookie;

  const LightIntensityDetailsScreen({
    super.key, 
    this.sensorData, 
    required this.deviceId,
    required this.sessionCookie,
  });

  @override
  State<LightIntensityDetailsScreen> createState() => _LightIntensityDetailsScreenState();
}

class _LightIntensityDetailsScreenState extends State<LightIntensityDetailsScreen> {
  String _selectedRange = 'daily'; 
  List<GraphPoint> _graphData = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchHistoryData('daily'); 
  }

  Future<void> _fetchHistoryData(String range) async {
    setState(() {
      _isLoading = true;
      _selectedRange = range;
      _errorMessage = '';
    });

    final url = Uri.parse("https://gridsphere.in/station/api/devices/${widget.deviceId}/history?range=$range");

    try {
      final response = await http.get(
        url,
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
        } else if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          readings = jsonResponse['data'];
        }

        if (readings.isNotEmpty) {
          List<GraphPoint> points = [];

          for (var r in readings) {
            // Parse Light Intensity
            double val = double.tryParse(r['light_intensity'].toString()) ?? 0.0;
            
            DateTime time;
            if (r['timestamp'] != null) {
              try {
                time = DateTime.parse(r['timestamp'].toString());
              } catch (e) {
                time = DateTime.now(); 
              }
            } else {
              time = DateTime.now();
            }

            points.add(GraphPoint(time: time, value: val));
          }

          // Sort by time ascending
          points.sort((a, b) => a.time.compareTo(b.time));

          if (mounted) {
            setState(() {
              _graphData = points;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _graphData = [];
              _isLoading = false;
              _errorMessage = "No data available for this period.";
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Server error: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Connection error";
        });
      }
      debugPrint("Error fetching light history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentLux = widget.sensorData?['light_intensity'] ?? 0.0;
    double maxLux = 0.0;
    double avgLux = 0.0;
    String maxTime = "--";
    
    if (_graphData.isNotEmpty) {
      // Find Peak Intensity
      final maxPoint = _graphData.reduce((curr, next) => curr.value > next.value ? curr : next);
      maxLux = maxPoint.value;
      maxTime = DateFormat('hh:mm a').format(maxPoint.time);

      // Calculate Average (Useful for daily light integral estimation)
      double sum = _graphData.fold(0, (prev, element) => prev + element.value);
      avgLux = sum / _graphData.length;

      if (_selectedRange != 'daily') {
        currentLux = _graphData.last.value;
      }
    } else {
      maxLux = currentLux;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Light Analysis",
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),

      // Removed FloatingActionButton and BottomNavigationBar

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Insight Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7), // Light Amber bg
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFF59D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.bot, size: 20, color: Color(0xFFF57F17)),
                      const SizedBox(width: 8),
                      Text(
                        "AI Insight",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF57F17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Light levels are sufficient for photosynthesis. Peak intensity observed around $maxTime. Cloud cover is minimal.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFF9A825),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Time Filter Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab("Today", "daily"),
                  _buildTab("Week", "weekly"),
                  _buildTab("Month", "monthly"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Main Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    "Peak Intensity",
                    "${maxLux.toStringAsFixed(0)} lx",
                    Icons.wb_sunny,
                    Colors.amber,
                    maxTime,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    "Avg Intensity",
                    "${avgLux.toStringAsFixed(0)} lx",
                    Icons.trending_up,
                    Colors.orange,
                    _selectedRange == 'daily' ? "Daytime Avg" : "Daily Avg",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chart Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
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
                  Text(
                    "Solar Radiation Trend",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 250, 
                    width: double.infinity,
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                      : _errorMessage.isNotEmpty
                          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                          : CustomPaint(
                              painter: _LightChartPainter(
                                  dataPoints: _graphData,
                                  color: Colors.amber, 
                                  range: _selectedRange,
                              ),
                            ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, String rangeKey) {
    final isSelected = _selectedRange == rangeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _fetchHistoryData(rangeKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF166534) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Light Chart (Amber Theme)
class _LightChartPainter extends CustomPainter {
  final List<GraphPoint> dataPoints;
  final Color color;
  final String range;

  _LightChartPainter({
    required this.dataPoints, 
    required this.color,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    const double leftMargin = 40.0;
    const double bottomMargin = 20.0;
    final double chartWidth = size.width - leftMargin;
    final double chartHeight = size.height - bottomMargin;

    if (dataPoints.isNotEmpty) {
      final textStyle = TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'Inter');
      final firstTime = dataPoints.first.time;
      final lastTime = dataPoints.last.time;
      final totalDuration = lastTime.difference(firstTime).inMinutes;

      for (int i = 0; i <= 4; i++) {
        double percent = i / 4.0;
        DateTime labelTime = firstTime.add(Duration(minutes: (totalDuration * percent).toInt()));
        
        String labelText = "";
        if (range == 'daily') {
           labelText = DateFormat('HH:mm').format(labelTime);
        } else if (range == 'weekly') {
           labelText = DateFormat('E').format(labelTime); 
        } else {
           labelText = DateFormat('d/M').format(labelTime); 
        }

        final textSpan = TextSpan(text: labelText, style: textStyle);
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();
        
        double xPos = leftMargin + (chartWidth * percent) - (textPainter.width / 2);
        
        if (i == 0) xPos = leftMargin;
        if (i == 4) xPos = size.width - textPainter.width;

        textPainter.paint(canvas, Offset(xPos, chartHeight + 5));
      }
    }

    if (dataPoints.isEmpty) {
        final path = Path();
        path.moveTo(leftMargin, chartHeight / 2);
        path.lineTo(size.width, chartHeight / 2);
        canvas.drawPath(path, paint);
        return;
    } 

    double minVal = 0.0;
    double maxVal = dataPoints.map((e) => e.value).reduce(max);
    
    // Light varies greatly, ensure scale fits
    if (maxVal < 100) maxVal = 100;
    else maxVal = (maxVal * 1.1).ceilToDouble();
    
    double yRange = maxVal - minVal;

    final textStyle = TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'Inter');

    for (int i = 0; i <= 4; i++) {
      double value = minVal + (yRange * i / 4);
      double yPos = chartHeight - (chartHeight * i / 4);
      
      // Use "k" suffix for large numbers to save space
      String label = value >= 1000 ? "${(value/1000).toStringAsFixed(1)}k" : value.toStringAsFixed(0);
      
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, yPos - textPainter.height / 2));

      final gridPaint = Paint()
        ..color = Colors.grey.shade200
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftMargin, yPos), Offset(size.width, yPos), gridPaint);
    }

    final path = Path();
    final firstTime = dataPoints.first.time;
    final totalDuration = dataPoints.last.time.difference(firstTime).inMinutes;

    for (int i = 0; i < dataPoints.length; i++) {
        final point = dataPoints[i];
        
        double timeDiff = point.time.difference(firstTime).inMinutes.toDouble();
        double x = leftMargin;
        if (totalDuration > 0) {
            x += ((timeDiff / totalDuration) * chartWidth);
        } else {
            x += chartWidth / 2;
        }
        
        double normalizedY = (point.value - minVal) / yRange;
        double y = chartHeight - (normalizedY * chartHeight);
        
        if (i == 0) {
            path.moveTo(x, y);
        } else {
            path.lineTo(x, y);
        }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, chartHeight)
      ..lineTo(leftMargin, chartHeight)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}