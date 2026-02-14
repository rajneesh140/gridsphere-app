import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/dashboard_screen.dart'; // Import Dashboard

const Color brandGreen = Color(0xFF166534);

class OnboardingUIScreen extends StatefulWidget {
  const OnboardingUIScreen({super.key});

  @override
  State<OnboardingUIScreen> createState() => _OnboardingUIScreenState();
}

class _OnboardingUIScreenState extends State<OnboardingUIScreen> {
  String? selectedIndustry;

  final List<_IndustryItem> industries = [
    _IndustryItem(
      title: "Chemical",
      subtitle: "Hazardous gas & levels tracking",
      icon: Icons.science,
    ),
    _IndustryItem(
      title: "Cement",
      subtitle: "Dust & particulate matter control",
      icon: Icons.factory,
    ),
    _IndustryItem(
      title: "Oil and Gas",
      subtitle: "Leak detection & flame monitoring",
      icon: Icons.local_fire_department,
    ),
    _IndustryItem(
      title: "Pharmaceutical",
      subtitle: "Sterile environment control",
      icon: Icons.medical_services,
    ),
    _IndustryItem(
      title: "Power Plant / Energy",
      subtitle: "Turbine & pressure monitoring",
      icon: Icons.flash_on,
    ),
    _IndustryItem(
      title: "Smart City",
      subtitle: "AQI, noise & flood monitoring",
      icon: Icons.location_city,
    ),
    _IndustryItem(
      title: "Manufacturing",
      subtitle: "Machine & worker monitoring",
      icon: Icons.precision_manufacturing,
    ),
  ];

  /// ✅ Save Industry
  Future<void> _saveIndustry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_industry', selectedIndustry!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              SizedBox(
                height: 72,
                width: 72,
                child: Image.asset(
                  "assets/mainlogo.png", // Changed to match other screens pattern if needed, keeping mainlogo.png as per file
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.public, size: 72, color: brandGreen),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Select Your Industry",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Tailor your dashboard to track the metrics\nthat matter most to your operations.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: industries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = industries[index];
                    final bool isSelected = selectedIndustry == item.title;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          selectedIndustry = item.title;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? brandGreen.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? brandGreen : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? brandGreen.withOpacity(0.15)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.icon,
                                color: brandGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: brandGreen,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedIndustry == null
                      ? null
                      : () async {
                          await _saveIndustry();
                          debugPrint(
                              "Selected Industry Saved: $selectedIndustry");

                          // --- UPDATED: Navigation to Dashboard (Final Step) ---
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const DashboardScreen()),
                              (route) => false, // Clears back stack
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedIndustry == null
                        ? Colors.grey.shade300
                        : brandGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    "CONTINUE",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selectedIndustry == null
                          ? Colors.grey.shade600
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndustryItem {
  final String title;
  final String subtitle;
  final IconData icon;

  _IndustryItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
