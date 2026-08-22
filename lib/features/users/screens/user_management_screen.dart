import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/screens/add_user_screen.dart';
import 'package:vpn_agent_app/features/users/screens/edit_user_screen.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool withBorder;
  final VoidCallback? onTap;
  final LinearGradient? gradient;

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
    this.gradient,
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
            gradient:
                gradient ??
                LinearGradient(
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

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({required this.color, this.size = 8});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final scale = 1.0 + (_ctrl.value * 0.4);
        final opacity = 1.0 - (_ctrl.value * 0.5);
        return SizedBox(
          width: widget.size * 2.5,
          height: widget.size * 2.5,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size * 1.8,
                    height: widget.size * 1.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.2 * opacity),
                    ),
                  ),
                ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardEntryAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  const _CardEntryAnimation({required this.child, required this.index});
  @override
  State<_CardEntryAnimation> createState() => _CardEntryAnimationState();
}

class _CardEntryAnimationState extends State<_CardEntryAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final delay = math.min(widget.index * 60, 400);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}

class UserManagementScreen extends StatefulWidget {
  final String initialFilter;

  const UserManagementScreen({super.key, this.initialFilter = 'all'});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();

  List<VpnUser> _users = [];
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String _currentSearchQuery = '';
  late String _currentFilter;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;

  static const List<Map<String, dynamic>> _filterOptions = [
    {
      'key': 'all',
      'label': 'All Users',
      'icon': Iconsax.people,
      'color': Colors.blueAccent,
    },
    {
      'key': 'active',
      'label': 'Active',
      'icon': Iconsax.tick_circle,
      'color': AppColors.accentGreen,
    },
    {
      'key': 'business',
      'label': 'Business',
      'icon': Iconsax.briefcase,
      'color': Color(0xFFF97316),
    },
    {
      'key': 'expiring',
      'label': 'Expiring',
      'icon': Iconsax.timer_1,
      'color': Colors.orangeAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _loadUsers(refresh: true);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_currentSearchQuery != _searchController.text) {
        setState(() {
          _currentSearchQuery = _searchController.text;
        });
        _loadUsers(refresh: true);
      }
    });
  }

  void _onFilterChanged(String filter) {
    if (_currentFilter == filter) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentFilter = filter;
    });
    _loadUsers(refresh: true);
  }

  Map<String, dynamic> get _activeFilterInfo {
    return _filterOptions.firstWhere((f) => f['key'] == _currentFilter);
  }

  String get _screenTitle {
    switch (_currentFilter) {
      case 'active':
        return 'Active Users';
      case 'business':
        return 'Business Users';
      case 'expiring':
        return 'Expiring Soon';
      default:
        return 'User Management';
    }
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _users.clear();
      });
    }

    final response = await _userService.getVpnUsers(
      page: _currentPage,
      search: _currentSearchQuery,
      filter: _currentFilter,
    );

    if (mounted) {
      setState(() {
        if (response != null) {
          if (refresh) {
            _users = response.users;
          } else {
            _users.addAll(response.users);
          }
          _lastPage = response.lastPage;
          _sortUsers();
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadUsers(refresh: false);
  }

  void _sortUsers() {
    _users.sort((a, b) {
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      DateTime dateA = DateTime.parse(a.expiryDate!);
      DateTime dateB = DateTime.parse(b.expiryDate!);
      return dateA.compareTo(dateB);
    });
  }

  Map<String, dynamic> _getExpiryStatus(String? dateStr, String status) {
    if (status == 'inactive') {
      return {
        'status_text': 'Inactive',
        'date_text': 'Paused',
        'color': Colors.grey,
        'icon': Iconsax.forbidden_2,
      };
    }

    if (dateStr == null) {
      return {
        'status_text': 'Active',
        'date_text': 'No Expiry',
        'color': AppColors.accentGreen,
        'icon': Iconsax.tick_circle,
      };
    }

    try {
      final expiryDate = DateTime.parse(dateStr);
      final now = DateTime.now();
      final dateOnlyExpiry = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );
      final dateOnlyNow = DateTime(now.year, now.month, now.day);
      final isExpired = dateOnlyNow.isAfter(dateOnlyExpiry);
      final daysRemaining = dateOnlyExpiry.difference(dateOnlyNow).inDays;
      final formattedDate = DateFormat('dd MMM yyyy').format(expiryDate);

      if (isExpired) {
        return {
          'status_text': 'Expired',
          'date_text': formattedDate,
          'color': Colors.redAccent,
          'icon': Iconsax.close_circle,
        };
      } else if (daysRemaining <= 7) {
        return {
          'status_text': '${daysRemaining}d left',
          'date_text': formattedDate,
          'color': Colors.orangeAccent,
          'icon': Iconsax.timer_1,
        };
      } else {
        return {
          'status_text': 'Active',
          'date_text': formattedDate,
          'color': AppColors.accentGreen,
          'icon': Iconsax.tick_circle,
        };
      }
    } catch (e) {
      return {
        'status_text': 'Error',
        'date_text': 'Invalid',
        'color': Colors.grey,
        'icon': Iconsax.warning_2,
      };
    }
  }

  Color _getPlanColor(String? planName) {
    if (planName == null) return Colors.white;
    final name = planName.toLowerCase();
    if (name.contains('gold')) return const Color(0xFFFFD700);
    if (name.contains('vip') || name.contains('premium'))
      return const Color(0xFFBF5AF2);
    if (name.contains('silver') || name.contains('basic'))
      return const Color(0xFFACCEF7);
    if (name.contains('private')) return const Color(0xFFFF2D55);
    return Colors.white;
  }

  void _showGlassDeleteConfirm(VpnUser user) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(24),
            opacity: 0.15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.trash,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Delete User?",
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "This action cannot be undone.\nRemove '${user.username}'?",
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ScaleButton(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final success = await _userService.deleteUser(
                            user.id,
                          );
                          if (success) {
                            _loadUsers(refresh: true);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("User deleted successfully"),
                                  backgroundColor: AppColors.accentGreen,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Delete",
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

  @override
  Widget build(BuildContext context) {
    final Color filterColor = _activeFilterInfo['color'];
    final onlineCount = _users.where((u) => u.isOnline).length;
    final businessCount = _users.where((u) => u.hasBusinessPlan).length;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _screenTitle,
            key: ValueKey(_screenTitle),
            style: GoogleFonts.exo2(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.0,
            ),
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
          if (onlineCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D3EE).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(width: 5),
                      Text(
                        "$onlineCount",
                        style: GoogleFonts.spaceMono(
                          color: const Color(0xFF22D3EE),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: LiquidGlassContainer(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                opacity: 0.1,
                child: Row(
                  children: [
                    Icon(Iconsax.people, size: 14, color: filterColor),
                    const SizedBox(width: 6),
                    Text(
                      "${_users.length}",
                      style: GoogleFonts.spaceMono(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildFilterChips(),
                if (!_isLoading && _users.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _buildMiniStats(onlineCount, businessCount),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
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
                              cursorColor: filterColor,
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
                                setState(() => _currentSearchQuery = '');
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
                const SizedBox(height: 4),
                Expanded(
                  child: _isLoading
                      ? _buildShimmerLoading()
                      : _users.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async => _loadUsers(refresh: true),
                          color: filterColor,
                          backgroundColor: const Color(0xFF2C2C2E),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: _users.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _users.length) {
                                if (_currentPage < _lastPage) {
                                  return _buildLoadMoreButton();
                                }
                                return _buildPageIndicator();
                              }
                              return _CardEntryAnimation(
                                index: index,
                                child: _buildGlassUserCard(_users[index]),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleButton(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddUserScreen()),
          );
          if (result == true) _loadUsers(refresh: true);
        },
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.all(16),
          gradient: const LinearGradient(
            colors: [AppColors.accentGreen, Color(0xFF00CC88)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: const Icon(Iconsax.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildMiniStats(int onlineCount, int businessCount) {
    return Row(
      children: [
        if (onlineCount > 0) ...[
          _buildMiniStatChip("Online", "$onlineCount", const Color(0xFF22D3EE)),
          const SizedBox(width: 8),
        ],
        if (businessCount > 0) ...[
          _buildMiniStatChip(
            "Business",
            "$businessCount",
            const Color(0xFFF97316),
          ),
          const SizedBox(width: 8),
        ],
        if (_lastPage > 1)
          _buildMiniStatChip(
            "Page",
            "$_currentPage/$_lastPage",
            Colors.white.withOpacity(0.6),
          ),
      ],
    );
  }

  Widget _buildMiniStatChip(String label, String value, Color color) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      opacity: 0.04,
      withBorder: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _filterOptions.map((option) {
            final String key = option['key'];
            final String label = option['label'];
            final IconData icon = option['icon'];
            final Color color = option['color'];
            final bool isSelected = _currentFilter == key;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ScaleButton(
                onTap: () => _onFilterChanged(key),
                scaleAmount: 0.95,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.18)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? color.withOpacity(0.5)
                          : Colors.white.withOpacity(0.06),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? color
                            : Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: GoogleFonts.ibmPlexSans(
                          color: isSelected
                              ? color
                              : Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(5, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(20),
              opacity: 0.04,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
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
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 80,
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
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    final Color filterColor = _activeFilterInfo['color'];
    final IconData filterIcon = _activeFilterInfo['icon'];
    final String filterLabel = _activeFilterInfo['label'];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: filterColor.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: filterColor.withOpacity(0.08)),
            ),
            child: Icon(
              _currentSearchQuery.isEmpty ? filterIcon : Iconsax.search_status,
              size: 44,
              color: filterColor.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _currentSearchQuery.isEmpty
                ? (_currentFilter == 'all'
                      ? "No users found"
                      : "No $filterLabel users")
                : "No results for '$_currentSearchQuery'",
            style: GoogleFonts.exo2(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentSearchQuery.isEmpty
                ? (_currentFilter == 'all'
                      ? "Add your first user to get started"
                      : "Try a different filter")
                : "Try a different search term",
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
          ),
          if (_currentFilter != 'all' && _currentSearchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ScaleButton(
              onTap: () => _onFilterChanged('all'),
              child: LiquidGlassContainer(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                opacity: 0.06,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.people,
                      size: 14,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Show All Users",
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentGreen,
                ),
              )
            : ScaleButton(
                onTap: _loadMoreUsers,
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  opacity: 0.06,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.arrow_down_1,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Load More",
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "($_currentPage/$_lastPage)",
                        style: GoogleFonts.spaceMono(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    if (_users.isEmpty) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: Text(
          "${_users.length} users loaded",
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.2),
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassUserCard(VpnUser user) {
    final expiryInfo = _getExpiryStatus(user.expiryDate, user.status);
    final Color statusColor = expiryInfo['color'];
    final IconData statusIcon = expiryInfo['icon'];
    final String statusText = expiryInfo['status_text'];
    final String dateText = expiryInfo['date_text'];
    final Color planColor = _getPlanColor(user.planName);
    final bool isBusiness = user.hasBusinessPlan;
    final bool isOnline = user.isOnline;
    final bool hasExtraSlots = user.extraDeviceSlots > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScaleButton(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditUserScreen(user: user)),
          );
          if (result == true) _loadUsers(refresh: true);
        },
        scaleAmount: 0.98,
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(22),
          opacity: isBusiness ? 0.07 : 0.05,
          tintColor: isBusiness ? const Color(0xFFF97316) : null,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isBusiness
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
                            color: isBusiness
                                ? const Color(0xFFF97316).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                            width: isBusiness ? 2.0 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : "U",
                            style: GoogleFonts.exo2(
                              color: isBusiness
                                  ? const Color(0xFFF97316)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      if (isBusiness)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
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
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isOnline)
                        Positioned(
                          left: -3,
                          top: -3,
                          child: _PulsingDot(
                            color: const Color(0xFF22D3EE),
                            size: 7,
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
                            if (isOnline) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF22D3EE,
                                  ).withOpacity(0.1),
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
                            Icon(Iconsax.flash_1, size: 11, color: planColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                user.planName ?? "No Plan",
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBusiness) ...[
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
                                  border: Border.all(
                                    color: const Color(
                                      0xFFF97316,
                                    ).withOpacity(0.25),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  user.businessPlanName ?? "Business",
                                  style: GoogleFonts.ibmPlexSans(
                                    color: const Color(0xFFF97316),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (hasExtraSlots) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Iconsax.mobile,
                                      size: 8,
                                      color: Colors.blueAccent,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "+${user.extraDeviceSlots}",
                                      style: GoogleFonts.spaceMono(
                                        color: Colors.blueAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          statusText,
                          style: GoogleFonts.ibmPlexSans(
                            color: statusColor,
                            fontSize: 10,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.calendar_1,
                          size: 12,
                          color: Colors.white.withOpacity(0.35),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateText,
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ScaleButton(
                    onTap: () => _showGlassDeleteConfirm(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.trash,
                            size: 12,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Remove",
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
