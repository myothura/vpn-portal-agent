import 'package:flutter/material.dart';
import 'package:vpn_agent_app/core/services/notification_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/auth/screens/login_screen.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';
import 'package:vpn_agent_app/core/navigation/app_transitions.dart';

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

    // A two-second sleep used to sit here purely to let the splash be seen.
    // Startup already does real work — Hive, Firebase, the RemoteConfig fetch,
    // notification setup — so the splash shows for as long as it needs to and
    // no longer. Padding it just made every launch two seconds slower.

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

        Navigator.of(context)
            .pushReplacement(AppTransitions.fadeThrough(const MainScaffold()));
      } else {
        Navigator.of(context)
            .pushReplacement(AppTransitions.fadeThrough(const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately empty. The Android launch theme already shows the app icon
    // until Flutter's first frame, and that native splash cannot be skipped —
    // drawing a second logo here made the icon appear, vanish, and reappear.
    // A plain background hands over to it seamlessly.
    return const Scaffold(backgroundColor: AppColors.background);
  }
}
