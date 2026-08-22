import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

// --- Reusable UI Components (Consistent with Dashboard) ---

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
    final radius = borderRadius ?? BorderRadius.circular(24);
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

// --- Main Screen ---

class DeviceSlotManagementScreen extends StatefulWidget {
  const DeviceSlotManagementScreen({super.key});

  @override
  State<DeviceSlotManagementScreen> createState() =>
      _DeviceSlotManagementScreenState();
}

class _DeviceSlotManagementScreenState
    extends State<DeviceSlotManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  final ScrollController _scrollController = ScrollController();

  List<VpnUser> _users = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;

  int _maxSlots = 5;
  int _slotPrice = 1000;
  bool _isSettingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    _loadUsers(refresh: true);
    _searchController.addListener(() {
      _onSearchChanged();
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.get(
        '${ApiConfig.baseUrl}/settings/app-config',
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'];
        if (mounted) {
          setState(() {
            _slotPrice =
                int.tryParse(data['device_slot_price'].toString()) ?? 1000;
            _maxSlots = int.tryParse(data['max_device_limit'].toString()) ?? 5;
            _isSettingsLoaded = true;
          });
        }
      }
    } catch (e) {
      print("Error settings: $e");
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadUsers(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage < _lastPage) {
      _loadUsers(refresh: false);
    }
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _users.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final response = await _userService.getVpnUsers(
      page: _currentPage,
      search: _searchController.text,
    );

    if (mounted) {
      setState(() {
        if (response != null) {
          if (refresh) {
            _users = response.users;
          } else {
            _users.addAll(response.users);
          }
          if (_currentPage < response.lastPage) _currentPage++;
          _lastPage = response.lastPage;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _buySlot(VpnUser user) async {
    HapticFeedback.mediumImpact();
    bool? confirm = await _showConfirmDialog(
      title: "Buy Extra Slot",
      content: "Add 1 slot for '${user.username}'?",
      cost: _slotPrice,
      isDestructive: false,
    );

    if (confirm == true) {
      final success = await _userService.addDeviceSlots(user.id, 1);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Slot added successfully!"),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        _loadUsers(refresh: true);
      }
    }
  }

  Future<void> _removeSlot(VpnUser user) async {
    HapticFeedback.mediumImpact();
    bool? confirm = await _showConfirmDialog(
      title: "Remove Slot",
      content: "Remove 1 extra slot from '${user.username}'?",
      isDestructive: true,
    );

    if (confirm == true) {
      final success = await _userService.removeDeviceSlots(user.id, 1);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Slot removed!"),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        _loadUsers(refresh: true);
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    int? cost,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.all(24),
            opacity: 0.15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.redAccent.withOpacity(0.1)
                        : AppColors.accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDestructive ? Iconsax.trash : Iconsax.add_circle,
                    size: 32,
                    color: isDestructive
                        ? Colors.redAccent
                        : AppColors.accentGreen,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (cost != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.coin,
                          size: 18,
                          color: AppColors.accentGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${NumberFormat('#,##0').format(cost)} Ks",
                          style: GoogleFonts.spaceMono(
                            color: AppColors.accentGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDestructive
                                ? Colors.redAccent.withOpacity(0.8)
                                : AppColors.accentGreen,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDestructive
                                    ? Colors.redAccent.withOpacity(0.3)
                                    : AppColors.accentGreen.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "Confirm",
                              style: GoogleFonts.ibmPlexSans(
                                color: isDestructive
                                    ? Colors.white
                                    : Colors.black,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Device Slots",
          style: GoogleFonts.exo2(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.arrow_left_2,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSettingsLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  opacity: 0.1,
                  tintColor: Colors.blueAccent,
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.setting_2,
                        size: 14,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Max: $_maxSlots",
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Background
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

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 6,
                  ),
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    opacity: 0.06,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.search_normal,
                            color: Colors.white.withOpacity(0.35),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              cursorColor: Colors.blueAccent,
                              decoration: InputDecoration(
                                hintText: "Search user by name...",
                                hintStyle: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.only(
                                  bottom: 2,
                                ),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            ScaleButton(
                              onTap: () {
                                _searchController.clear();
                                _loadUsers(refresh: true);
                              },
                              child: Icon(
                                Iconsax.close_circle,
                                size: 18,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                if (_isSettingsLoaded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          opacity: 0.05,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.coin,
                                size: 12,
                                color: Colors.orangeAccent.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${NumberFormat('#,##0').format(_slotPrice)} / slot",
                                style: GoogleFonts.spaceMono(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          opacity: 0.05,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.people,
                                size: 12,
                                color: Colors.blueAccent.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${_users.length} users",
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading && _users.isEmpty
                      ? _buildShimmer()
                      : _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.08),
                                  ),
                                ),
                                child: Icon(
                                  Iconsax.mobile,
                                  size: 44,
                                  color: Colors.blueAccent.withOpacity(0.3),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "No users found",
                                style: GoogleFonts.exo2(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Search for a user to manage slots",
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadUsers(refresh: true),
                          color: AppColors.accentGreen,
                          backgroundColor: const Color(0xFF2C2C2E),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _users.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _users.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54,
                                    ),
                                  ),
                                );
                              }
                              return _buildUserSlotCard(_users[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(22),
            opacity: 0.04,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 110,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 70,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 28,
                      width: 55,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.white.withOpacity(0.03), height: 1),
                const SizedBox(height: 14),
                SizedBox(
                  height: 70,
                  child: Row(
                    children: List.generate(
                      4,
                      (j) => Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: j < 3 ? 10 : 0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSlotCard(VpnUser user) {
    int totalActive = 1 + (user.extraDeviceSlots);
    bool isMaxedOut = totalActive >= _maxSlots;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(18),
        opacity: isMaxedOut ? 0.07 : 0.05,
        tintColor: isMaxedOut ? Colors.orangeAccent : null,
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: user.hasBusinessPlan
                              ? [
                                  const Color(0xFFF97316).withOpacity(0.3),
                                  const Color(0xFFEA580C).withOpacity(0.15),
                                ]
                              : [
                                  AppColors.accentGreen.withOpacity(0.2),
                                  Colors.blueAccent.withOpacity(0.1),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: user.hasBusinessPlan
                              ? const Color(0xFFF97316).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                          width: user.hasBusinessPlan ? 2.0 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.exo2(
                            color: user.hasBusinessPlan
                                ? const Color(0xFFF97316)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    if (user.hasBusinessPlan)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F0F10),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Iconsax.briefcase,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (user.isOnline)
                      Positioned(
                        left: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22D3EE),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F0F10),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22D3EE).withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.username,
                              style: GoogleFonts.exo2(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isOnline) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22D3EE).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                "ONLINE",
                                style: GoogleFonts.spaceMono(
                                  color: const Color(0xFF22D3EE),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              user.planName ?? "No Plan",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (user.hasBusinessPlan) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF97316,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                user.businessPlanName ?? "BIZ",
                                style: GoogleFonts.ibmPlexSans(
                                  color: const Color(0xFFF97316),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMaxedOut
                        ? Colors.orangeAccent.withOpacity(0.12)
                        : AppColors.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMaxedOut
                          ? Colors.orangeAccent.withOpacity(0.25)
                          : AppColors.accentGreen.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.devices,
                        size: 13,
                        color: isMaxedOut
                            ? Colors.orangeAccent
                            : AppColors.accentGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "$totalActive/$_maxSlots",
                        style: GoogleFonts.spaceMono(
                          color: isMaxedOut
                              ? Colors.orangeAccent
                              : AppColors.accentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.white.withOpacity(0.04), height: 1),
            const SizedBox(height: 14),

            // Slots Grid
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _maxSlots,
                separatorBuilder: (c, i) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSlotItem(
                      icon: Iconsax.mobile,
                      color: AppColors.accentGreen,
                      label: "Base",
                      status: "Active",
                      isActive: true,
                    );
                  } else if (index < totalActive) {
                    return ScaleButton(
                      onTap: () => _removeSlot(user),
                      child: _buildSlotItem(
                        icon: Iconsax.mobile,
                        color: Colors.blueAccent,
                        label: "Extra",
                        status: "Active",
                        isActive: true,
                        isDestructive: true, // Shows X
                      ),
                    );
                  } else if (index == totalActive) {
                    return ScaleButton(
                      onTap: () => _buySlot(user),
                      child: _buildSlotItem(
                        icon: Iconsax.add,
                        color: Colors.amber, // Gold for spending money
                        label: "New",
                        status: "Buy Slot",
                        isActive: false,
                        isAction: true,
                      ),
                    );
                  } else {
                    return _buildSlotItem(
                      icon: Iconsax.lock,
                      color: Colors.white.withOpacity(0.2),
                      label: "Lock",
                      status: "Slot ${index + 1}",
                      isActive: false,
                      isLocked: true,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotItem({
    required IconData icon,
    required Color color,
    required String label,
    required String status,
    bool isActive = false,
    bool isAction = false,
    bool isDestructive = false,
    bool isLocked = false,
  }) {
    // Determine Background & Border based on state
    Color bgColor = Colors.transparent;
    Color borderColor = Colors.white.withOpacity(0.08);

    if (isActive) {
      bgColor = color.withOpacity(0.1);
      borderColor = color.withOpacity(0.4);
    } else if (isAction) {
      bgColor = color.withOpacity(0.05);
      borderColor = color.withOpacity(0.5); // Brighter border for Action
    } else if (isLocked) {
      bgColor = Colors.black.withOpacity(0.2);
    }

    return Container(
      width: 65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isLocked ? Colors.white.withOpacity(0.2) : color,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  color: isLocked
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Action Overlay (for Remove)
          if (isDestructive)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 10,
                  color: Colors.redAccent,
                ),
              ),
            ),

          // Action Overlay (for Add)
          if (isAction)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, size: 10, color: color),
              ),
            ),
        ],
      ),
    );
  }
}
