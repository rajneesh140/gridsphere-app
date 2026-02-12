import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this
import 'dart:async';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'session_manager.dart'; // Import SessionManager

class GoogleFonts {
  static TextStyle inter(
      {double? fontSize,
      FontWeight? fontWeight,
      Color? color,
      double? letterSpacing}) {
    return TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for animation/branding
    await Future.delayed(const Duration(seconds: 3));

    // Check for saved cookie
    final prefs = await SharedPreferences.getInstance();
    final String? sessionCookie = prefs.getString('session_cookie');

    if (mounted) {
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        // --- Set session in Singleton ---
        SessionManager().setSessionCookie(sessionCookie);

        // Cookie found -> Go to Dashboard (no params needed now)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // No cookie -> Go to Login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF166534),
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2)),
                child: Image.asset('assets/logo.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (c, e, s) => const Icon(Icons.public,
                        size: 64, color: Colors.white)),
              ),
              const SizedBox(height: 30),
              Text("Grid Sphere Pvt. Ltd.",
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text("AgriTech Solutions",
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5)),
              const SizedBox(height: 60),
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3),
            ],
          ),
        ),
      ),
    );
  }
}
