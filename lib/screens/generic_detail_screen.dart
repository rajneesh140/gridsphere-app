import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart' hide TextDirection;
import '../session_manager/session_manager.dart';
import '../widgets/home_back_button.dart';
import '../widgets/home_pop_scope.dart'; // Import HomePopScope

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

// Data Model for Graph Points
class GraphPoint {
  final DateTime time;
  final double value;

  GraphPoint({required this.time, required this.value});
}

class GenericDetailScreen extends StatefulWidget {
  final String title;
  final String sensorKey; // e.g., 'temp', 'humidity', 'soil_moisture'
  final String unit; // e.g., '°C', '%', 'lx'
  final IconData icon;
  final Color themeColor;
  final String deviceId;
  final Map<String, dynamic>?
      currentData; // Optional: Pass current data to show immediately

  const GenericDetailScreen({
    super.key,
    required this.title,
    required this.sensorKey,
    required this.unit,
    required this.icon,
    required this.themeColor,
    required this.deviceId,
    this.currentData,
  });

  @override
  State<GenericDetailScreen> createState() => _GenericDetailScreenState();
}

class _GenericDetailScreenState extends State<GenericDetailScreen> {
  String _selectedRange = '24h';
  List<GraphPoint> _graphData = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchHistoryData('24h');
  }

  Future<void> _fetchHistoryData(String range) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedRange = range;
      _errorMessage = '';
    });

    String apiRange = 'daily';
    if (range == '7d') apiRange = 'weekly';
    if (range == '30d') apiRange = 'monthly';

    final url = Uri.parse(
        "https://gridsphere.in/station/api/devices/${widget.deviceId}/history?range=$apiRange");

    try {
      final response = await http.get(
        url,
        headers: {
          'Cookie': SessionManager().sessionCookie, // Use SessionManager
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
        } else if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          readings = jsonResponse['data'];
        }

        if (readings.isNotEmpty) {
          List<GraphPoint> points = [];

          for (var r in readings) {
            var rawVal = r[widget.sensorKey];

            // Handle different key names in history API if they differ from sensorKey
            if (rawVal == null) {
              if (widget.sensorKey == 'air_temp')
                rawVal = r['temp'];
              else if (widget.sensorKey == 'soil_moisture')
                rawVal = r['surface_humidity'];
              else if (widget.sensorKey == 'soil_temp')
                rawVal = r['depth_temp'];
              else if (widget.sensorKey == 'wind')
                rawVal = r['wind_speed'];
              else if (widget.sensorKey == 'wind_speed')
                rawVal = r['wind_speed']; // Safety for wind_speed key
            }

            double val = double.tryParse(rawVal.toString()) ?? 0.0;

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

          points.sort((a, b) => a.time.compareTo(b.time));

          setState(() {
            _graphData = points;
            _isLoading = false;
          });
        } else {
          setState(() {
            _graphData = [];
            _isLoading = false;
            _errorMessage = "No data available for this period.";
          });
        }
      } else {
        _generateMockData(range);
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      _generateMockData(range);
    }
  }

  void _generateMockData(String range) {
    if (!mounted) return;

    final random = Random();
    List<GraphPoint> mockPoints = [];
    DateTime endDate = DateTime.now();
    int pointsCount = range == '24h' ? 24 : (range == '7d' ? 7 : 30);

    for (int i = 0; i < pointsCount; i++) {
      DateTime time;
      if (range == '24h') {
        time = endDate.subtract(Duration(hours: i));
      } else {
        time = endDate.subtract(Duration(days: i));
      }
      double base = 20.0 + random.nextDouble() * 10;

      mockPoints.add(GraphPoint(time: time, value: base));
    }
    mockPoints.sort((a, b) => a.time.compareTo(b.time));

    setState(() {
      _isLoading = false;
      _graphData = mockPoints;
      _errorMessage = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    double currentVal = 0.0;
    if (widget.currentData != null &&
        widget.currentData!.containsKey(widget.sensorKey)) {
      currentVal =
          double.tryParse(widget.currentData![widget.sensorKey].toString()) ??
              0.0;
    }

    double maxVal = 0.0;
    double minVal = 0.0;
    String maxTime = "--";
    String minTime = "--";

    if (_graphData.isNotEmpty) {
      final maxPoint = _graphData
          .reduce((curr, next) => curr.value > next.value ? curr : next);
      maxVal = maxPoint.value;
      maxTime = DateFormat('dd/MM hh:mm a').format(maxPoint.time);

      final minPoint = _graphData
          .reduce((curr, next) => curr.value < next.value ? curr : next);
      minVal = minPoint.value;
      minTime = DateFormat('dd/MM hh:mm a').format(minPoint.time);
    } else {
      maxVal = currentVal;
      minVal = currentVal;
    }

    // --- UPDATED: Use HomePopScope Wrapper ---
    return HomePopScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const HomeBackButton(),
          title: Text(
            widget.title,
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab("Day", "24h"),
                    _buildTab("Week", "7d"),
                    _buildTab("Month", "30d"),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      "Max",
                      "${maxVal.toStringAsFixed(1)}${widget.unit}",
                      Icons.arrow_upward,
                      Colors.red,
                      maxTime,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatBox(
                      "Min",
                      "${minVal.toStringAsFixed(1)}${widget.unit}",
                      Icons.arrow_downward,
                      Colors.blue,
                      minTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon,
                              color: widget.themeColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${widget.title} Trend",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: widget.themeColor))
                          : _errorMessage.isNotEmpty
                              ? Center(
                                  child: Text(_errorMessage,
                                      style:
                                          const TextStyle(color: Colors.red)))
                              : CustomPaint(
                                  painter: _DetailedChartPainter(
                                    dataPoints: _graphData,
                                    color: widget.themeColor,
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
      ),
    );
  }

  Widget _buildTab(String text, String rangeKey) {
    final isSelected = _selectedRange == rangeKey;
    final activeColor = widget.themeColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => _fetchHistoryData(rangeKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
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

  Widget _buildStatBox(
      String title, String value, IconData icon, Color color, String time) {
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Chart Painter
class _DetailedChartPainter extends CustomPainter {
  final List<GraphPoint> dataPoints;
  final Color color;
  final String range;

  _DetailedChartPainter({
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
          color.withOpacity(0.2),
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
      final textStyle =
          TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'Inter');
      final firstTime = dataPoints.first.time;
      final lastTime = dataPoints.last.time;
      final totalDuration = lastTime.difference(firstTime).inMinutes;

      for (int i = 0; i <= 4; i++) {
        double percent = i / 4.0;
        DateTime labelTime =
            firstTime.add(Duration(minutes: (totalDuration * percent).toInt()));

        String labelText = "";
        if (range == '24h') {
          labelText = DateFormat('HH:mm').format(labelTime);
        } else if (range == '7d') {
          labelText = DateFormat('E').format(labelTime);
        } else {
          labelText = DateFormat('dd/MM').format(labelTime);
        }

        final textSpan = TextSpan(text: labelText, style: textStyle);
        final textPainter =
            TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();

        double xPos =
            leftMargin + (chartWidth * percent) - (textPainter.width / 2);

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

    // --- Draw Y-Axis Labels ---
    double minVal = dataPoints.map((e) => e.value).reduce(min);
    double maxVal = dataPoints.map((e) => e.value).reduce(max);

    // Add buffer to look nicer
    minVal = (minVal - (minVal * 0.1)).floorToDouble();
    maxVal = (maxVal + (maxVal * 0.1)).ceilToDouble();
    if (minVal == maxVal) maxVal += 10; // Prevent div by zero

    double yRange = maxVal - minVal;

    final textStyle =
        TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'Inter');

    for (int i = 0; i <= 4; i++) {
      double value = minVal + (yRange * i / 4);
      double yPos = chartHeight - (chartHeight * i / 4);

      final textSpan =
          TextSpan(text: value.toStringAsFixed(1), style: textStyle);
      final textPainter =
          TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, yPos - textPainter.height / 2));

      final gridPaint = Paint()
        ..color = Colors.grey.shade200
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(leftMargin, yPos), Offset(size.width, yPos), gridPaint);
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
