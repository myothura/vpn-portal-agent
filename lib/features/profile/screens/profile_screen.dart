import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';

// Repositories & Services
import 'package:vpn_agent_app/features/auth/screens/login_screen.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart';
import 'package:vpn_agent_app/features/profile/bloc/profile_bloc.dart';
import 'package:vpn_agent_app/features/profile/models/profile_user_model.dart';
import 'package:vpn_agent_app/features/profile/repositories/profile_repository.dart';
import 'package:vpn_agent_app/features/profile/screens/manage_payment_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/send_notification_screen.dart';
import 'package:vpn_agent_app/features/agent_management/screens/agent_list_screen.dart';

// --- Reusable UI Components ---

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool withBorder;
  final VoidCallback? onTap;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.opacity = 0.08,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.tintColor,
    this.withBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24.r);
    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tintColor ?? Colors.white).withOpacity(opacity),
            borderRadius: radius,
            border: withBorder
                ? Border.all(color: Colors.white.withOpacity(0.12), width: 1.0)
                : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? Colors.white).withOpacity(opacity + 0.05),
                (tintColor ?? Colors.white).withOpacity(opacity),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;
  const ScaleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleAmount = 0.95,
  });
  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
        HapticFeedback.lightImpact();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// --- Main Screen ---

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProfileBloc(repository: ProfileRepository())..add(ProfileStarted()),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final AuthService _authService = AuthService();

  // --- Logic Helpers ---

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
          child: LiquidGlassContainer(
            opacity: 0.15,
            blurSigma: 20,
            borderRadius: BorderRadius.circular(24.r),
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDestructive
                        ? Colors.redAccent.withOpacity(0.15)
                        : AppColors.accentGreen.withOpacity(0.15),
                  ),
                  child: Icon(
                    isDestructive ? Iconsax.warning_2 : Iconsax.logout_1,
                    color: isDestructive
                        ? Colors.redAccent
                        : AppColors.accentGreen,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  title,
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  message,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: isDestructive
                                ? Colors.redAccent.withOpacity(0.25)
                                : AppColors.accentGreen.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: isDestructive
                                  ? Colors.redAccent.withOpacity(0.5)
                                  : AppColors.accentGreen.withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              confirmText,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTelegramDialog(BuildContext context, String currentUsername) {
    final controller = TextEditingController(text: currentUsername);
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
          child: LiquidGlassContainer(
            opacity: 0.15,
            borderRadius: BorderRadius.circular(24.r),
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Telegram Connection",
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  "Enter your Telegram username to sync notifications.",
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white70,
                    fontSize: 13.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                TextField(
                  controller: controller,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 16.sp,
                  ),
                  decoration: InputDecoration(
                    prefixText: "@ ",
                    prefixStyle: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFF229ED9),
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                    hintText: "username",
                    hintStyle: GoogleFonts.ibmPlexSans(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFF229ED9)),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ScaleButton(
                        onTap: () {
                          Navigator.pop(context);
                          context.read<ProfileBloc>().add(
                            ProfileTelegramUpdated(controller.text),
                          );
                        },
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF229ED9).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: const Color(0xFF229ED9).withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Save",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await _showConfirmDialog(
      context,
      title: "Confirm Logout",
      message: "Are you sure you want to log out of your agent account?",
      confirmText: "Logout",
      isDestructive: true,
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.successMessage!,
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage!,
                style: GoogleFonts.ibmPlexSans(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F0F10), Color(0xFF18181C)],
                  ),
                ),
              ),
            ),

            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Iconsax.arrow_left, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "SETTINGS",
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18.sp,
                  ),
                ),
                centerTitle: true,
              ),
              body: SafeArea(
                bottom: false,
                child: Builder(
                  builder: (context) {
                    if (state.status == ProfileStatus.loading &&
                        state.user == null) {
                      return const Center(child: GlassLoadingIndicator());
                    }

                    if (state.user == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.warning_2,
                              size: 50.sp,
                              color: Colors.white38,
                            ),
                            SizedBox(height: 16.h),
                            TextButton(
                              onPressed: () => context.read<ProfileBloc>().add(
                                ProfileStarted(),
                              ),
                              child: Text(
                                "Retry",
                                style: GoogleFonts.ibmPlexSans(
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final user = state.user!;

                    // --- Build List of Grid Items ---
                    // This prepares the items to be paired in rows later
                    List<Widget> gridItems = [];

                    // 1. Telegram
                    gridItems.add(
                      _buildGridCard(
                        icon: Icons.telegram,
                        title: "Telegram",
                        subtitle: "Link Account",
                        color: const Color(0xFF229ED9),
                        onTap: () => _showEditTelegramDialog(
                          context,
                          user.telegramUsername,
                        ),
                        isLinked: user.telegramUsername.isNotEmpty,
                      ),
                    );

                    // 2. Broadcast (Conditional)
                    if (user.canSendNoti) {
                      gridItems.add(
                        _buildGridCard(
                          icon: Iconsax.notification,
                          title: "Broadcast",
                          subtitle: "Send Alert",
                          color: Colors.orangeAccent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SendNotificationScreen(),
                            ),
                          ),
                        ),
                      );
                    }

                    // 3. Agent Management (Conditional)
                    if (user.canManageAgents) {
                      gridItems.add(
                        _buildGridCard(
                          icon: Iconsax.people,
                          title: "Agents",
                          subtitle: "Manage All",
                          color: AppColors.accentGreen,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AgentListScreen(),
                            ),
                          ),
                        ),
                      );
                    }

                    // 4. Logout (Added to Grid as per 2-card request)
                    gridItems.add(
                      _buildGridCard(
                        icon: Iconsax.logout,
                        title: "Log Out",
                        subtitle: "Exit App",
                        color: Colors.redAccent,
                        onTap: _handleLogout,
                        isDestructive: true,
                      ),
                    );

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGlassUserProfileCard(user),
                          SizedBox(height: 24.h),

                          Text(
                            "GENERAL",
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.white38,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // 1. Payment Methods (Full Width)
                          _buildFullWidthCard(
                            icon: Iconsax.card,
                            title: "Payment Methods",
                            color: Colors.purpleAccent,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<ProfileBloc>(),
                                    child: ManagePaymentScreen(
                                      initialMethods: user.paymentMethods,
                                    ),
                                  ),
                                ),
                              );
                            },
                            trailing: Text(
                              "${user.paymentMethods.length}",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // 2. Grid Items (2 Cards Per Row)
                          ..._buildGridRows(gridItems),

                          SizedBox(height: 40.h),
                          Center(
                            child: Text(
                              "App Version 1.0.0",
                              style: GoogleFonts.ibmPlexSans(
                                color: const Color(0xFF474D57),
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            if (state.status == ProfileStatus.updating)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(child: GlassLoadingIndicator()),
              ),
          ],
        );
      },
    );
  }

  // --- Helper to build Grid Rows from a List of Widgets ---
  List<Widget> _buildGridRows(List<Widget> items) {
    List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      // Get first item
      Widget item1 = items[i];
      // Get second item if exists
      Widget? item2 = (i + 1 < items.length) ? items[i + 1] : null;

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Expanded(child: item1),
              SizedBox(width: 12.w),
              Expanded(
                child: item2 ?? const SizedBox(), // Empty box if no second item
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildGlassUserProfileCard(ProfileUser user) {
    const Color themeColor = AppColors.accentGreen;

    return LiquidGlassContainer(
      opacity: 0.1,
      blurSigma: 20,
      borderRadius: BorderRadius.circular(24.r),
      padding: EdgeInsets.all(22.w),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58.w,
                height: 58.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor.withOpacity(0.15),
                  border: Border.all(
                    color: themeColor.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : "A",
                    style: GoogleFonts.exo2(
                      color: themeColor,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 18.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.exo2(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: themeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Agent Account",
                        style: GoogleFonts.ibmPlexSans(
                          color: themeColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          SizedBox(height: 20.h),
          _buildInfoRow("Email", user.email, Iconsax.sms, Colors.white70),
          SizedBox(height: 14.h),
          _buildInfoRow(
            "Telegram",
            user.telegramUsername.isNotEmpty
                ? "@${user.telegramUsername}"
                : "Not Linked",
            Icons.telegram,
            const Color(0xFF229ED9),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFF848E9C),
            fontSize: 14.sp,
          ),
        ),
        Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 180.w),
              child: Text(
                value,
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Icon(icon, color: iconColor, size: 16.sp),
          ],
        ),
      ],
    );
  }

  // --- 1. Full Width Card (For Payment Methods) ---
  Widget _buildFullWidthCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ScaleButton(
      onTap: onTap,
      scaleAmount: 0.98,
      child: LiquidGlassContainer(
        opacity: 0.08,
        blurSigma: 15,
        borderRadius: BorderRadius.circular(20.r),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: SizedBox(
          height: 32.h, // Adjusted height for Row layout
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(icon, color: color, size: 18.sp),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Iconsax.arrow_right_3,
                  color: Colors.white.withOpacity(0.2),
                  size: 16.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. Grid Card (For Other Actions - Vertical Layout) ---
  Widget _buildGridCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLinked = false,
    bool isDestructive = false,
  }) {
    return ScaleButton(
      onTap: onTap,
      scaleAmount: 0.95,
      child: LiquidGlassContainer(
        opacity: isDestructive ? 0.05 : 0.08,
        tintColor: isDestructive ? Colors.red : null,
        blurSigma: 15,
        borderRadius: BorderRadius.circular(20.r),
        padding: EdgeInsets.all(16.w),
        child: SizedBox(
          height: 100.h, // Taller for vertical layout
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22.sp),
                  ),
                  if (isLinked)
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 8.sp, color: Colors.black),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                title,
                style: GoogleFonts.ibmPlexSans(
                  color: isDestructive ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white38,
                    fontSize: 11.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GlassLoadingIndicator extends StatelessWidget {
  const GlassLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentGreen,
              ),
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }
}
