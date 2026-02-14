import 'package:flutter/material.dart';
import 'password_screen.dart'; // Import navigation target

class GoogleFonts {
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

class RegisterUIScreen extends StatefulWidget {
  const RegisterUIScreen({super.key});

  @override
  State<RegisterUIScreen> createState() => _RegisterUIScreenState();
}

class _RegisterUIScreenState extends State<RegisterUIScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _emailVerified = false;
  bool _showOtp = false;
  bool _loading = false;

  late AnimationController _otpAnimController;
  late Animation<double> _otpAnimation;

  static const Color primaryGreen = Color(0xFF166534);

  @override
  void initState() {
    super.initState();
    _otpAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _otpAnimation = CurvedAnimation(
      parent: _otpAnimController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _otpAnimController.dispose();
    super.dispose();
  }

  void _onVerifyEmail() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _emailVerified = true;
          _showOtp = true;
        });
        _otpAnimController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: primaryGreen,
        // Added Back Button logic
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // Extend body behind app bar to keep green background uniform
        extendBodyBehindAppBar: true,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Logo
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
                      errorBuilder: (_, __, ___) => const Icon(Icons.public,
                          size: 60, color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Create Account",
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Card
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
                        children: [
                          _buildField(
                            controller: _nameController,
                            label: "Name",
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 20),

                          _buildField(
                            controller: _phoneController,
                            label: "Phone Number",
                            icon: Icons.phone,
                            keyboard: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            readOnly: _emailVerified,
                            decoration: InputDecoration(
                              labelText: "Email",
                              labelStyle: TextStyle(
                                color: _emailVerified
                                    ? primaryGreen
                                    : Colors.grey.shade700,
                              ),
                              prefixIcon: const Icon(Icons.email),
                              suffixIcon: _emailVerified
                                  ? const Icon(Icons.check_circle,
                                      color: primaryGreen)
                                  : null,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: primaryGreen, width: 2),
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? "Enter email" : null,
                          ),

                          const SizedBox(height: 16),

                          // Verify Email Button
                          if (!_showOtp)
                            SizedBox(
                              height: 50,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _onVerifyEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "Verify Email",
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                          // OTP Section
                          SizeTransition(
                            sizeFactor: _otpAnimation,
                            axisAlignment: -1,
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Enter OTP",
                                    labelStyle:
                                        TextStyle(color: Colors.grey.shade700),
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: primaryGreen, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 50,
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    // --- UPDATED: Navigate to Password Screen ---
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PasswordScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      "Continue",
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(icon),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),
      validator: (v) => v!.isEmpty ? "Required field" : null,
    );
  }
}
