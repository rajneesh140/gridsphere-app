import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart' hide TextDirection; 
import '../screens/chat_screen.dart';   
import '../screens/alerts_screen.dart'; 

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

class SurfaceTemperatureDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? sensorData;
  final String deviceId;
  final String sessionCookie;

  const SurfaceTemperatureDetailsScreen({
    super.key, 
    this.sensorData, 
    required this.deviceId,
    required this.sessionCookie,
  });

  @override
  State<SurfaceTemperatureDetailsScreen> createState() => _SurfaceTemperatureDetailsScreenState();
}

class _SurfaceTemperatureDetailsScreenState extends State<SurfaceTemperatureDetailsScreen> {
  String _selectedRange = 'daily'; 
  List<GraphPoint> _graphData = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Defined Maroon Color
  final Color _maroonColor = const Color(0xFF800000);

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
            // Parse Surface Temp
            double val = double.tryParse(r['surface_temp'].toString()) ?? 0.0;
            
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
      debugPrint("Error fetching surface temp history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double currentTemp = widget.sensorData?['surface_temp'] ?? 0.0;
    double maxTemp = 0.0;
    double minTemp = 0.0;
    String maxTime = "--";
    String minTime = "--";
    
    if (_graphData.isNotEmpty) {
      final maxPoint = _graphData.reduce((curr, next) => curr.value > next.value ? curr : next);
      maxTemp = maxPoint.value;
      maxTime = DateFormat('hh:mm a').format(maxPoint.time);

      final minPoint = _graphData.reduce((curr, next) => curr.value < next.value ? curr : next);
      minTemp = minPoint.value;
      minTime = DateFormat('hh:mm a').format(minPoint.time);

      if (_selectedRange != 'daily') {
        currentTemp = _graphData.last.value;
      }
    } else {
      maxTemp = currentTemp; 
      minTemp = currentTemp;
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
          "Surface Temperature",
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),      

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Insight Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE), // Red 50
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFCDD2)), // Red 100
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.bot, size: 20, color: _maroonColor), 
                      const SizedBox(width: 8),
                      Text(
                        "AI Insight",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _maroonColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Surface temperature affects germination and microbial activity. Current readings indicate moderate levels suitable for vegetative growth.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _maroonColor, 
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
                    "Max Surf Temp",
                    "${maxTemp.toStringAsFixed(1)}°C",
                    Icons.arrow_upward,
                    _maroonColor,
                    maxTime,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    "Min Surf Temp",
                    "${minTemp.toStringAsFixed(1)}°C",
                    Icons.arrow_downward,
                    Colors.orange[900]!,
                    minTime,
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
                    "Surface Temperature Trend",
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
                      ? Center(child: CircularProgressIndicator(color: _maroonColor))
                      : _errorMessage.isNotEmpty
                          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                          : CustomPaint(
                              painter: _SurfaceTempChartPainter(
                                  dataPoints: _graphData,
                                  color: _maroonColor, 
                                  range: _selectedRange,
                              ),
                            ),
                  ),
                  const SizedBox(height: 16),
                  // Labels are drawn by the painter
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
            color: isSelected ? _maroonColor : Colors.transparent,
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

class _SurfaceTempChartPainter extends CustomPainter {
  final List<GraphPoint> dataPoints;
  final Color color;
  final String range;

  _SurfaceTempChartPainter({
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

    // --- Draw X-Axis Labels ---
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

    double minVal = dataPoints.map((e) => e.value).reduce(min);
    double maxVal = dataPoints.map((e) => e.value).reduce(max);
    
    // Add buffer
    minVal = (minVal - 2).floorToDouble();
    maxVal = (maxVal + 2).ceilToDouble();
    double yRange = maxVal - minVal;
    if (yRange == 0) yRange = 1;

    final textStyle = TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'Inter');

    // --- Draw Y-Axis Labels ---
    for (int i = 0; i <= 4; i++) {
      double value = minVal + (yRange * i / 4);
      double yPos = chartHeight - (chartHeight * i / 4);
      
      final textSpan = TextSpan(text: value.toStringAsFixed(1), style: textStyle);
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