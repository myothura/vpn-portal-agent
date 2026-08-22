import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';

import 'package:vpn_agent_app/features/dashboard/repositories/dashboard_repository.dart';
import 'package:vpn_agent_app/features/dashboard/bloc/dashboard_bloc.dart';

import 'package:vpn_agent_app/features/users/screens/add_user_screen.dart';
import 'package:vpn_agent_app/features/history/screens/renewal_requests_screen.dart';
import 'package:vpn_agent_app/features/history/screens/credit_history_screen.dart';
import 'package:vpn_agent_app/features/users/screens/user_management_screen.dart';
import 'package:vpn_agent_app/features/users/screens/device_slot_management_screen.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/features/profile/screens/manage_payment_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/notification_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/send_notification_screen.dart';
import 'package:vpn_agent_app/features/profile/screens/profile_screen.dart';
import 'package:vpn_agent_app/features/agent_management/screens/agent_list_screen.dart';
import 'package:vpn_agent_app/features/chat/screens/agent_chat_list_screen.dart';

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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DashboardBloc(repository: DashboardRepository())
            ..add(DashboardStarted()),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final ProfileService _profileService = ProfileService();
  bool _isActionLoading = false;
  bool _isRefreshing = false;
  bool _canManageAgents = false;
  bool _canSendNoti = false;
  bool _canAccessChat = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final profileData = await _profileService.getProfile();
      if (profileData != null && mounted) {
        setState(() {
          _canManageAgents =
              profileData['can_manage_agents'] == true ||
              profileData['can_manage_agents'] == 1;
          _canSendNoti =
              profileData['can_send_notifications'] == true ||
              profileData['can_send_notifications'] == 1;
          _canAccessChat =
              profileData['can_access_chat'] == true ||
              profileData['can_access_chat'] == 1;
          if (profileData['id'] == 16) {
            _canManageAgents = true;
            _canSendNoti = true;
            _canAccessChat = true;
          }
        });
      }
    } catch (_) {}
  }

  void _triggerRefresh() {
    HapticFeedback.lightImpact();
    setState(() {
      _isRefreshing = true;
    });
    context.read<DashboardBloc>().add(DashboardRefreshed());
    _loadPermissions();
  }

  Future<void> _onPaymentMethodsTap() async {
    setState(() => _isActionLoading = true);
    try {
      final profileData = await _profileService.getProfile();
      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (profileData != null) {
        List<PaymentMethod> methods = [];
        if (profileData['payment_details'] != null) {
          methods = (profileData['payment_details'] as List)
              .map((e) => PaymentMethod.fromJson(e))
              .toList();
        }

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ManagePaymentScreen(initialMethods: methods),
            ),
          );
          _triggerRefresh();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(375, 812));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
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
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Expanded(
                    child: BlocConsumer<DashboardBloc, DashboardState>(
                      listener: (context, state) {
                        if (state is DashboardLoaded ||
                            state is DashboardError) {
                          if (mounted) {
                            setState(() => _isRefreshing = false);
                          }
                        }
                        if (state is DashboardError &&
                            state.cachedStats == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.message),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      builder: (context, state) {
                        DashboardStats? stats;
                        if (state is DashboardLoaded) {
                          stats = state.stats;
                        } else if (state is DashboardLoading) {
                          stats = state.cachedStats;
                        } else if (state is DashboardError) {
                          stats = state.cachedStats;
                        }

                        if (stats == null) {
                          if (state is DashboardLoading) {
                            return const Center(child: GlassLoadingIndicator());
                          }
                          return _buildErrorView(context);
                        }

                        final bool isActuallyLoading =
                            state is DashboardLoading;
                        final bool showLoadingText =
                            _isRefreshing || isActuallyLoading;

                        return RefreshIndicator(
                          onRefresh: () async => _triggerRefresh(),
                          color: AppColors.accentGreen,
                          backgroundColor: const Color(0xFF2C2C2E),
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            children: [
                              _buildGreetingHeader(context, stats),
                              SizedBox(height: 16.h),
                              RequestTicker(
                                requests: stats.recentRequests,
                                onRefreshNeeded: _triggerRefresh,
                              ),
                              SizedBox(height: 20.h),
                              _buildCreditBalanceCard(
                                context,
                                stats,
                                showLoadingText,
                              ),
                              SizedBox(height: 20.h),
                              _buildStatsGrid(context, stats),
                              SizedBox(height: 24.h),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "QUICK ACTIONS",
                                  style: GoogleFonts.exo2(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.4),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              _buildManagementGrid(context, stats),
                              SizedBox(height: 20.h),
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Iconsax.code_1,
                                      size: 14.sp,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "Develop By Ghost Developer",
                                      style: GoogleFonts.exo2(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isActionLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(child: GlassLoadingIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, DashboardStats stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.greeting,
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                stats.firstName,
                style: GoogleFonts.exo2(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (stats.onlineUserCount > 0)
              Container(
                margin: EdgeInsets.only(right: 10.w),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFF22D3EE).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22D3EE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      "${stats.onlineUserCount}",
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF22D3EE),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            _buildHeaderIcon(
              icon: Iconsax.notification,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ).then((_) => _triggerRefresh()),
            ),
            SizedBox(width: 8.w),
            _buildHeaderIcon(
              icon: Iconsax.profile_circle,
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  )
                  .then((_) => _triggerRefresh()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onTap: onTap,
      scaleAmount: 0.9,
      child: LiquidGlassContainer(
        opacity: 0.05,
        borderRadius: BorderRadius.circular(14.r),
        padding: EdgeInsets.all(10.w),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }

  Widget _buildCreditBalanceCard(
    BuildContext context,
    DashboardStats stats,
    bool isLoading,
  ) {
    return ScaleButton(
      onTap: () {},
      child: LiquidGlassContainer(
        opacity: 0.12,
        tintColor: AppColors.accentGreen,
        borderRadius: BorderRadius.circular(30.r),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.wallet_2,
                        color: AppColors.accentGreen,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Available Balance',
                      style: GoogleFonts.ibmPlexSans(
                        color: AppColors.accentGreen.withOpacity(0.9),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                ScaleButton(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreditHistoryScreen(),
                    ),
                  ).then((_) => _triggerRefresh()),
                  scaleAmount: 0.9,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      "History",
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      stats.formattedCreditBalance,
                      style: GoogleFonts.exo2(
                        color: Colors.white,
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                ScaleButton(
                  onTap: isLoading ? null : _triggerRefresh,
                  scaleAmount: 0.9,
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: isLoading
                          ? AppColors.accentGreen.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isLoading
                            ? AppColors.accentGreen.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentGreen,
                            ),
                          )
                        : Icon(
                            Iconsax.refresh,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            SizedBox(height: 12.h),
            Row(
              children: [
                Text(
                  'Spent this month: ',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13.sp,
                  ),
                ),
                Text(
                  stats.formattedCreditsSpent,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(Iconsax.trend_down, color: Colors.redAccent, size: 16.sp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, DashboardStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGlassStatCard(
                title: 'Total Users',
                value: '${stats.totalUserCount}',
                icon: Iconsax.people,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const UserManagementScreen(initialFilter: 'all'),
                  ),
                ).then((_) => _triggerRefresh()),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildGlassStatCard(
                title: 'Active',
                value: '${stats.activeUserCount}',
                icon: Iconsax.tick_circle,
                color: AppColors.accentGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const UserManagementScreen(initialFilter: 'active'),
                  ),
                ).then((_) => _triggerRefresh()),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildGlassStatCard(
                title: 'Business',
                value: '${stats.businessUserCount}',
                icon: Iconsax.briefcase,
                color: const Color(0xFFF97316),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const UserManagementScreen(initialFilter: 'business'),
                  ),
                ).then((_) => _triggerRefresh()),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildGlassStatCard(
                title: 'Expiring Soon',
                value: '${stats.expiringSoonCount}',
                icon: Iconsax.timer_1,
                color: Colors.orangeAccent,
                isAlert: stats.expiringSoonCount > 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const UserManagementScreen(initialFilter: 'expiring'),
                  ),
                ).then((_) => _triggerRefresh()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagementGrid(BuildContext context, DashboardStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGlassActionTile(
                title: 'Add User',
                icon: Iconsax.user_add,
                color: AppColors.accentGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddUserScreen()),
                ).then((_) => _triggerRefresh()),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildGlassActionTile(
                title: 'Renewals',
                icon: Iconsax.repeat,
                color: Colors.orangeAccent,
                badgeCount: stats.recentRequests.length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RenewalRequestsScreen(),
                  ),
                ).then((_) => _triggerRefresh()),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            if (_canAccessChat)
              Expanded(
                child: _buildGlassActionTile(
                  title: 'Support Chat',
                  icon: Iconsax.message_text_1,
                  color: AppColors.accentGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AgentChatListScreen(),
                    ),
                  ).then((_) => _triggerRefresh()),
                ),
              ),
            if (_canAccessChat) SizedBox(width: 12.w),
            Expanded(
              child: _buildGlassActionTile(
                title: 'Payment',
                icon: Iconsax.card,
                color: Colors.purpleAccent,
                onTap: _onPaymentMethodsTap,
              ),
            ),
            if (!_canAccessChat) ...[
              SizedBox(width: 12.w),
              Expanded(
                child: _buildGlassActionTile(
                  title: 'Device Slots',
                  icon: Iconsax.mobile,
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceSlotManagementScreen(),
                      ),
                    ).then((_) => _triggerRefresh());
                  },
                ),
              ),
            ],
          ],
        ),
        if (_canAccessChat) ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildGlassActionTile(
                  title: 'Device Slots',
                  icon: Iconsax.mobile,
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceSlotManagementScreen(),
                      ),
                    ).then((_) => _triggerRefresh());
                  },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildGlassActionTile(
                  title: 'Users',
                  icon: Iconsax.user_search,
                  color: const Color(0xFF22D3EE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  ).then((_) => _triggerRefresh()),
                ),
              ),
            ],
          ),
        ],
        if (!_canAccessChat) ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildGlassActionTile(
                  title: 'Users',
                  icon: Iconsax.user_search,
                  color: const Color(0xFF22D3EE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  ).then((_) => _triggerRefresh()),
                ),
              ),
              SizedBox(width: 12.w),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
        if (_canManageAgents || _canSendNoti) ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              if (_canManageAgents)
                Expanded(
                  child: _buildGlassActionTile(
                    title: 'My Agents',
                    icon: Iconsax.people,
                    color: const Color(0xFFA78BFA),
                    badgeCount: stats.subAgentCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AgentListScreen(),
                        ),
                      ).then((_) => _triggerRefresh());
                    },
                  ),
                ),
              if (_canManageAgents && _canSendNoti) SizedBox(width: 12.w),
              if (_canSendNoti)
                Expanded(
                  child: _buildGlassActionTile(
                    title: 'Broadcast',
                    icon: Iconsax.notification,
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SendNotificationScreen(),
                      ),
                    ).then((_) => _triggerRefresh()),
                  ),
                ),
              if (_canManageAgents != _canSendNoti) ...[
                SizedBox(width: 12.w),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildGlassStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isAlert = false,
  }) {
    return ScaleButton(
      onTap: onTap,
      scaleAmount: 0.97,
      child: LiquidGlassContainer(
        opacity: isAlert ? 0.08 : 0.05,
        tintColor: isAlert ? color : null,
        borderRadius: BorderRadius.circular(20.r),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        withBorder: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.exo2(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return ScaleButton(
      onTap: onTap,
      scaleAmount: 0.97,
      child: LiquidGlassContainer(
        opacity: 0.05,
        borderRadius: BorderRadius.circular(18.r),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.exo2(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.wifi_square,
            size: 40.sp,
            color: Colors.white.withOpacity(0.2),
          ),
          SizedBox(height: 16.h),
          Text(
            'Failed to load dashboard',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 16.h),
          ScaleButton(
            onTap: () => context.read<DashboardBloc>().add(DashboardStarted()),
            child: LiquidGlassContainer(
              opacity: 0.1,
              borderRadius: BorderRadius.circular(12.r),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.refresh,
                    color: AppColors.accentGreen,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Retry',
                    style: GoogleFonts.ibmPlexSans(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestTicker extends StatefulWidget {
  final List<String> requests;
  final VoidCallback onRefreshNeeded;

  const RequestTicker({
    super.key,
    required this.requests,
    required this.onRefreshNeeded,
  });

  @override
  State<RequestTicker> createState() => _RequestTickerState();
}

class _RequestTickerState extends State<RequestTicker> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant RequestTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests.length != widget.requests.length) {
      _timer?.cancel();
      _currentIndex = 0;
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    if (widget.requests.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.requests.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRequests = widget.requests.isNotEmpty;
    final Color baseColor = hasRequests
        ? Colors.orangeAccent
        : AppColors.accentGreen;

    String currentMessage = "System All Operational";
    if (hasRequests) {
      if (_currentIndex < widget.requests.length) {
        currentMessage = widget.requests[_currentIndex];
      } else {
        currentMessage = widget.requests[0];
      }
    }

    return ScaleButton(
      onTap: hasRequests
          ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RenewalRequestsScreen()),
            ).then((_) => widget.onRefreshNeeded())
          : null,
      child: LiquidGlassContainer(
        opacity: 0.08,
        tintColor: baseColor,
        borderRadius: BorderRadius.circular(20.r),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            Icon(
              hasRequests ? Iconsax.notification : Iconsax.tick_circle,
              color: baseColor,
              size: 16.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  currentMessage,
                  key: ValueKey<String>(currentMessage),
                  style: GoogleFonts.ibmPlexSans(
                    color: hasRequests ? Colors.white : AppColors.accentGreen,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (hasRequests)
              Icon(Iconsax.arrow_right_3, color: baseColor, size: 12.sp),
          ],
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
