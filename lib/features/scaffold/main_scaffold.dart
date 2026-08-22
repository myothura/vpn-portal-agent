// File: lib/features/scaffold/main_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:vpn_agent_app/features/history/screens/renewal_requests_screen.dart';
import 'package:vpn_agent_app/features/users/screens/user_management_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    DashboardScreen(),
    UserManagementScreen(),
    RenewalRequestsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1a1a1a), Color(0xFF2c3e50)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          IndexedStack(index: _selectedIndex, children: _screens),
        ],
      ),
      bottomNavigationBar: _buildGlassBottomNavBar(),
    );
  }

  Widget _buildGlassBottomNavBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.houseChimney),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.users),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.solidBell),
              label: 'Requests',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: AppColors.accentGreen,
          unselectedItemColor: Colors.white54,
          onTap: _onItemTapped,
          backgroundColor: Colors.black.withOpacity(0.3),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}
