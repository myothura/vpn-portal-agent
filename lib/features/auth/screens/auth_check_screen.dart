import 'package:flutter/material.dart';
import 'package:vpn_agent_app/core/services/notification_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/auth/screens/login_screen.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';
import 'package:vpn_agent_app/shared_widgets/glass_loading_dialog.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initialize notification channels (no API calls yet).
    // Guarded: notification setup is not worth blocking startup for. Without
    // this, any throw here leaves the user on the splash screen forever.
    try {
      print("🚀 Initializing Notification Service...");
      await NotificationService.initialize();
      print("✅ Notification Service Initialized");
    } catch (e) {
      debugPrint("Notification init failed (continuing): $e");
    }

    // 2. Loading
    await Future.delayed(const Duration(seconds: 2));

    // 3. Check login status
    print("🔐 Checking Token...");
    final authService = AuthService();
    final bool isLoggedIn = await authService.hasToken();
    print("🔐 Token Check Result: $isLoggedIn");

    if (mounted) {
      if (isLoggedIn) {
        // 4. Register FCM token AFTER confirming auth
        await NotificationService.registerFcmToken();
        print("📱 FCM Token Registered");

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScaffold()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkBackground, Color(0xFF2C3E50)],
          ),
        ),
        child: const Center(
          child: GlassLoadingDialog(message: "Starting App..."),
        ),
      ),
    );
  }
}
