// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/dashboard/screens/dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ⭐️ No Stack, No Overlay. Just return Dashboard directly.
    return const Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: DashboardScreen(),
    );
  }
}
