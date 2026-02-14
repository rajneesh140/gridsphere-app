import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';

class HomePopScope extends StatelessWidget {
  final Widget child;

  const HomePopScope({
    super.key,
    required this.child,
  });

  Future<bool> _onWillPop(BuildContext context) async {
    // Navigate directly to Dashboard (Home) and clear stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
    // Return false to prevent the default pop behavior since we are handling navigation manually
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Using WillPopScope for broader compatibility.
    // If you are on Flutter > 3.12, consider PopScope, but WillPopScope is safer for now.
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: child,
    );
  }
}
