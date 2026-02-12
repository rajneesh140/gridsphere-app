import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Import for saving session
import 'dashboard_screen.dart';
import 'session_manager.dart'; // Import SessionManager

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final String _baseUrl = "https://gridsphere.in/station/api";

  // --- CONSTANT: User Agent ---
  // Critical: Must match the one used in DashboardScreen exactly to keep session alive.
  final String _userAgent = "FlutterApp";

  // --- COOKIE JAR ---
  // Store cookies in a map to automatically handle deduplication
  final Map<String, String> _cookieJar = {};

  // --- ROBUST PARSER ---
  // Extracts "key=value" pairs and ignores attributes like 'path', 'expires', etc.
  void _updateCookieJar(String? rawCookies) {
    if (rawCookies == null || rawCookies.isEmpty) return;

    // Regex to find "Key=Value" patterns.
    final regex = RegExp(r'([a-zA-Z0-9_-]+)=([^;]+)');
    final matches = regex.allMatches(rawCookies);

    final Set<String> ignoreKeys = {
      'expires',
      'max-age',
      'path',
      'domain',
      'secure',
      'httponly',
      'samesite'
    };

    for (final match in matches) {
      String key = match.group(1)?.trim() ?? "";
      String value = match.group(2)?.trim() ?? "";

      if (key.isNotEmpty && !ignoreKeys.contains(key.toLowerCase())) {
        _cookieJar[key] = value;
      }
    }
  }

  // Helper to convert the Map back into a header string
  String _getCookieHeader() {
    return _cookieJar.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // --- STEP 1: Get CSRF Token ---
        final csrfUrl = Uri.parse('$_baseUrl/getCSRF');
        final csrfResponse = await http.get(
          csrfUrl,
          // FIX: Send User-Agent here so the session is bound to it immediately
          headers: {'User-Agent': _userAgent},
        );

        if (csrfResponse.statusCode == 200) {
          final csrfData = jsonDecode(csrfResponse.body);
          final String csrfName = csrfData['csrf_name'];
          final String csrfValue = csrfData['csrf_token'];

          // 1. Update Cookie Jar with CSRF cookies
          _updateCookieJar(csrfResponse.headers['set-cookie']);

          if (_cookieJar.isNotEmpty) {
            // --- STEP 2: Perform Login ---
            final loginUrl = Uri.parse('$_baseUrl/login');

            final loginResponse = await http.post(
              loginUrl,
              headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "Cookie": _getCookieHeader(), // Send clean cookies
                "User-Agent": _userAgent, // Send matching User-Agent
              },
              body: {
                "username": _idController.text.trim(),
                "password":
                    _passwordController.text.trim(), // Added trim for safety
                csrfName: csrfValue,
              },
            );

            if (loginResponse.statusCode == 200) {
              final loginData = jsonDecode(loginResponse.body);

              if (loginData['status'] == true ||
                  loginData['status'] == 'success') {
                if (mounted) {
                  // 2. Update Cookie Jar with Session Rotation cookies from Login
                  _updateCookieJar(loginResponse.headers['set-cookie']);

                  final String finalCookies = _getCookieHeader();
                  debugPrint("✅ Login Success! Clean Cookies: $finalCookies");

                  // --- SAVE SESSION PERSISTENTLY ---
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('session_cookie', finalCookies);

                  // --- SET SESSION IN MANAGER ---
                  SessionManager().setSessionCookie(finalCookies);

                  // --- STEP 3: Fetch Initial Device for Location ---
                  // We need to fetch devices here to get the lat/lon for the session
                  await _fetchAndStoreInitialLocation();

                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          const DashboardScreen(), // No longer need to pass cookie
                    ),
                  );
                }
              } else {
                _showError(loginData['message'] ?? 'Login failed');
              }
            } else {
              _showError('Login Error: ${loginResponse.statusCode}');
            }
          } else {
            _showError('Session initialization failed (No Cookie)');
          }
        } else {
          _showError('Server Error: ${csrfResponse.statusCode}');
        }
      } catch (e) {
        _showError('Connection failed. Check internet.');
        debugPrint("Login Exception: $e");
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // New helper to fetch device info immediately after login to populate SessionManager location
  Future<void> _fetchAndStoreInitialLocation() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getDevices'),
        headers: {
          'Cookie': SessionManager().sessionCookie,
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> deviceList = [];

        if (data is List) {
          deviceList = data;
        } else if (data is Map) {
          if (data['data'] is List) {
            deviceList = data['data'];
          } else if (data['devices'] is List) {
            deviceList = data['devices'];
          }
        }

        if (deviceList.isNotEmpty) {
          final device = deviceList[0];
          double lat =
              double.tryParse(device['latitude']?.toString() ?? "0.0") ?? 0.0;
          double lon =
              double.tryParse(device['longitude']?.toString() ?? "0.0") ?? 0.0;

          // Store in SessionManager
          SessionManager().setLocation(lat, lon);
          debugPrint("📍 Initial Location Stored: $lat, $lon");
        }
      }
    } catch (e) {
      debugPrint("Error fetching initial location: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF166534),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 60,
                      height: 60,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.public,
                          size: 60,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Welcome Back",
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Sign in to access your farm data",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Login",
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          TextFormField(
                            controller: _idController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: "User ID",
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF166534), width: 2)),
                            ),
                            validator: (value) => value!.isEmpty
                                ? "Please enter your User ID"
                                : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _obscurePassword
                                        ? Icons.remove_red_eye
                                        : Icons.remove_red_eye_outlined,
                                    color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF166534), width: 2)),
                            ),
                            validator: (value) => value!.isEmpty
                                ? "Please enter your password"
                                : null,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF166534),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text("Sign In",
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
