import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../screens/dashboard_screen.dart';
import '../agriculture/protection_screen.dart';
import '../agriculture/soil_screen.dart';
import '../screens/alerts_screen.dart';

// Assuming you have a GoogleFonts class or helper somewhere, if not define it or import it.
// Reusing your existing GoogleFonts helper for consistency.
class GoogleFontsHelper {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String deviceId;
  final Map<String, dynamic>? sensorData;
  final double latitude;
  final double longitude;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    this.deviceId = "",
    this.sensorData,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == 2 || index == currentIndex) return; // 2 is the FAB placeholder

    // Helper to replace the current screen with a new one
    // Using pushReplacement for smoother transitions between main tabs (optional, push is also fine)
    // However, Dashboard is usually the root.
    // To keep your existing stack logic:

    if (index == 0) {
      // Go to Dashboard (Root)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else if (index == 1) {
      // Go to Protection
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProtectionScreen(deviceId: deviceId),
        ),
      );
    } else if (index == 3) {
      // Go to Soil
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SoilScreen(
            deviceId: deviceId,
            sensorData: sensorData,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
      );
    } else if (index == 4) {
      // Go to Alerts
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AlertsScreen(
            deviceId: deviceId,
            sensorData: sensorData,
            latitude: latitude,
            longitude: longitude,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF166534),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      selectedLabelStyle:
          GoogleFontsHelper.inter(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: GoogleFontsHelper.inter(fontSize: 12),
      onTap: (index) => _onItemTapped(context, index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.shieldCheck), label: "Protection"),
        BottomNavigationBarItem(
            icon: SizedBox(height: 24), label: ""), // Space for FAB
        BottomNavigationBarItem(icon: Icon(LucideIcons.layers), label: "Soil"),
        BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none), label: "Alerts"),
      ],
    );
  }
}
