import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/background_service.dart'; // Import Background Service
import 'services/notification_service.dart'; // Import Notification Service

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize the Background Service (Critical for preventing the crash)
  await BackgroundService.initialize();

  // 3. Initialize the Notification Service
  await NotificationService.initialize();

  runApp(const GridSphereApp());
}

class GridSphereApp extends StatelessWidget {
  const GridSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grid Sphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF166534),
        // Use a slight off-white/grey for the scaffold to make white cards pop
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
        // Define a default card theme
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
