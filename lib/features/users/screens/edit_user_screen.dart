import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/users/models/plan_model.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
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
    final radius = borderRadius ?? BorderRadius.circular(20);
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

class EditUserScreen extends StatefulWidget {
  final VpnUser user;
  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen>
    with SingleTickerProviderStateMixin {
  final _userService = UserManagementService();
  List<Plan> _plans = [];
  Plan? _selectedPlan;

  List<BusinessPlan> _businessPlans = [];
  BusinessPlan? _selectedBusinessPlan;
  bool _hasBusinessPlan = false;
  String? _currentBusinessPlanName;
  bool _businessLoading = false;

  final _monthsController = TextEditingController(text: '0');
  final _daysController = TextEditingController(text: '0');
  final _passwordController = TextEditingController();

  String _status = 'active';
  bool _isLoading = false;
  bool _isFetching = true;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _status = widget.user.status;
    _hasBusinessPlan = widget.user.hasBusinessPlan;
    _currentBusinessPlanName = widget.user.businessPlanName;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );

    _fetchData();
    _monthsController.addListener(() => setState(() {}));
    _daysController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _monthsController.dispose();
    _daysController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final results = await Future.wait([
      _userService.getAvailablePlans(),
      _userService.getBusinessPlans(),
    ]);

    _plans = results[0] as List<Plan>;
    _businessPlans = results[1] as List<BusinessPlan>;

    if (mounted) {
      if (_plans.isNotEmpty) {
        try {
          _selectedPlan = _plans.firstWhere(
            (p) => p.planName == widget.user.planName,
          );
        } catch (e) {
          _selectedPlan = _plans.first;
        }
      }
      if (_businessPlans.isNotEmpty) {
        _selectedBusinessPlan = _businessPlans.first;
      }
      setState(() => _isFetching = false);
      _animController.forward();
    }
  }

  Future<void> _updateUser() async {
    HapticFeedback.mediumImpact();
    if (_selectedPlan == null) return;
    setState(() => _isLoading = true);

    final months = int.tryParse(_monthsController.text) ?? 0;
    final days = int.tryParse(_daysController.text) ?? 0;

    final success = await _userService.updateUser(
      userId: widget.user.id,
      planId: _selectedPlan!.id,
      months: months,
      days: days,
      status: _status,
      password: _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User updated successfully"),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Update failed."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _assignBusinessPlan() async {
    if (_selectedBusinessPlan == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _businessLoading = true);

    final result = await _userService.assignBusinessPlan(
      widget.user.id,
      _selectedBusinessPlan!.id,
    );

    if (mounted) {
      setState(() => _businessLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: const Color(0xFFF97316),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeBusinessPlan() async {
    HapticFeedback.mediumImpact();
    setState(() => _businessLoading = true);

    final result = await _userService.removeBusinessPlan(widget.user.id);

    if (mounted) {
      setState(() => _businessLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRemoveBusinessConfirm() {
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
                    color: const Color(0xFFF97316).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.briefcase,
                    color: Color(0xFFF97316),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Remove Business Plan?",
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "This will revoke Business server access for '${widget.user.username}'. Standard servers will remain active.",
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
                        onTap: () {
                          Navigator.pop(ctx);
                          _removeBusinessPlan();
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF97316).withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Remove",
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
    int months = int.tryParse(_monthsController.text) ?? 0;
    int days = int.tryParse(_daysController.text) ?? 0;
    int basePlanPrice = _selectedPlan?.price ?? 0;
    int chargePrice = _hasBusinessPlan
        ? (widget.user.businessPlanPrice ?? basePlanPrice)
        : basePlanPrice;
    double dailyRate = chargePrice / 30;
    int totalDays = (months * 30) + days;
    int totalCost = (dailyRate * totalDays).ceil();
    bool isBusinessPricing =
        _hasBusinessPlan && widget.user.businessPlanPrice != null;

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
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
          title: Text(
            "Edit User",
            style: GoogleFonts.exo2(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
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
              child: _isFetching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGreen,
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  10,
                                  24,
                                  isKeyboardOpen ? 250 : 120,
                                ),
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  children: [
                                    _buildUserGlassCard(),
                                    const SizedBox(height: 32),
                                    _buildEditForm(),
                                    const SizedBox(height: 32),
                                    _buildBusinessPlanSection(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (!_isFetching && !isKeyboardOpen)
              Positioned(
                left: 24,
                right: 24,
                bottom: 30,
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(24),
                  opacity: 0.15,
                  blurSigma: 25,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  withBorder: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isBusinessPricing
                                ? "BUSINESS RENEWAL"
                                : "RENEWAL COST",
                            style: GoogleFonts.exo2(
                              color: isBusinessPricing
                                  ? const Color(0xFFF97316).withOpacity(0.8)
                                  : Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                "${NumberFormat('#,##0').format(totalCost)}",
                                style: GoogleFonts.spaceMono(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isBusinessPricing) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF97316,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "${NumberFormat('#,##0').format(chargePrice)}/mo",
                                    style: GoogleFonts.spaceMono(
                                      color: const Color(0xFFF97316),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      ScaleButton(
                        onTap: _isLoading ? null : _updateUser,
                        child: LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(16),
                          opacity: 0.2,
                          tintColor: AppColors.accentGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  children: [
                                    const Icon(
                                      Iconsax.refresh,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Update",
                                      style: GoogleFonts.exo2(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGlassCard() {
    String expiryText = "No Expiry";
    Color expiryColor = AppColors.accentGreen;
    if (widget.user.expiryDate != null) {
      try {
        final exp = DateTime.parse(widget.user.expiryDate!);
        final now = DateTime.now();
        final days = exp.difference(now).inDays;
        expiryText = DateFormat('dd MMM yyyy').format(exp);
        if (days < 0) {
          expiryColor = Colors.redAccent;
        } else if (days <= 7) {
          expiryColor = Colors.orangeAccent;
          expiryText = "$expiryText (${days}d left)";
        }
      } catch (_) {}
    }

    return LiquidGlassContainer(
      opacity: 0.1,
      tintColor: _hasBusinessPlan ? const Color(0xFFF97316) : Colors.blueAccent,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      withBorder: true,
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _hasBusinessPlan
                            ? [
                                const Color(0xFFF97316).withOpacity(0.3),
                                const Color(0xFFEA580C).withOpacity(0.15),
                              ]
                            : [
                                AppColors.accentGreen.withOpacity(0.2),
                                Colors.blueAccent.withOpacity(0.2),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _hasBusinessPlan
                            ? const Color(0xFFF97316).withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
                        width: _hasBusinessPlan ? 2.0 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.user.username.isNotEmpty
                            ? widget.user.username[0].toUpperCase()
                            : "U",
                        style: GoogleFonts.exo2(
                          color: _hasBusinessPlan
                              ? const Color(0xFFF97316)
                              : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_hasBusinessPlan)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
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
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (widget.user.isOnline)
                    Positioned(
                      left: -2,
                      top: -2,
                      child: Container(
                        width: 14,
                        height: 14,
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.user.username,
                            style: GoogleFonts.exo2(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.user.isOnline) ...[
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          opacity: 0.15,
                          tintColor: _status == 'active'
                              ? AppColors.accentGreen
                              : Colors.redAccent,
                          child: Text(
                            _status.toUpperCase(),
                            style: GoogleFonts.ibmPlexSans(
                              color: _status == 'active'
                                  ? AppColors.accentGreen
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_hasBusinessPlan &&
                            _currentBusinessPlanName != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFFF97316,
                                ).withOpacity(0.25),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              _currentBusinessPlanName!,
                              style: GoogleFonts.ibmPlexSans(
                                color: const Color(0xFFF97316),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (widget.user.extraDeviceSlots > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
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
                                  size: 9,
                                  color: Colors.blueAccent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "+${widget.user.extraDeviceSlots}",
                                  style: GoogleFonts.spaceMono(
                                    color: Colors.blueAccent,
                                    fontSize: 9,
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
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Iconsax.flash_1,
                size: 12,
                color: Colors.white.withOpacity(0.35),
              ),
              const SizedBox(width: 6),
              Text(
                widget.user.planName ?? "No Plan",
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Icon(
                Iconsax.calendar_1,
                size: 12,
                color: expiryColor.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                expiryText,
                style: GoogleFonts.ibmPlexSans(
                  color: expiryColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdown<Plan>(
          label: "CHANGE PLAN",
          value: _selectedPlan,
          items: _plans,
          onChanged: (p) => setState(() => _selectedPlan = p),
          displayText: (p) => p.planName,
          icon: Iconsax.box,
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "EXTEND DURATION",
                style: GoogleFonts.exo2(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCounterInput(
                controller: _monthsController,
                label: "Months",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCounterInput(
                controller: _daysController,
                label: "Days",
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildPasswordInput(),
        const SizedBox(height: 24),
        _buildDropdown<String>(
          label: "ACCOUNT STATUS",
          value: _status,
          items: ['active', 'inactive'],
          onChanged: (s) => setState(() => _status = s!),
          displayText: (s) => s.toUpperCase(),
          icon: _status == 'active' ? Iconsax.tick_circle : Iconsax.forbidden_2,
          iconColor: _status == 'active'
              ? AppColors.accentGreen
              : Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildBusinessPlanSection() {
    const orangeAccent = Color(0xFFF97316);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: orangeAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "BUSINESS PLAN",
              style: GoogleFonts.exo2(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(20),
          opacity: _hasBusinessPlan ? 0.08 : 0.05,
          tintColor: _hasBusinessPlan ? orangeAccent : null,
          padding: const EdgeInsets.all(20),
          child: _hasBusinessPlan
              ? _buildActiveBusinessPlan(orangeAccent)
              : _buildAssignBusinessPlan(orangeAccent),
        ),
      ],
    );
  }

  Widget _buildActiveBusinessPlan(Color orangeAccent) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: orangeAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: orangeAccent.withOpacity(0.3)),
              ),
              child: Icon(Iconsax.briefcase, color: orangeAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentBusinessPlanName ?? "Business Plan",
                    style: GoogleFonts.exo2(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Iconsax.tick_circle, size: 12, color: orangeAccent),
                      const SizedBox(width: 6),
                      Text(
                        "Active — Business servers unlocked",
                        style: GoogleFonts.ibmPlexSans(
                          color: orangeAccent.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: Colors.white.withOpacity(0.06), height: 1),
        const SizedBox(height: 16),
        ScaleButton(
          onTap: _businessLoading ? null : _showRemoveBusinessConfirm,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: _businessLoading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Iconsax.close_circle,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Remove Business Plan",
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignBusinessPlan(Color orangeAccent) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(
                Iconsax.briefcase,
                color: Colors.white.withOpacity(0.3),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No Business Plan",
                    style: GoogleFonts.exo2(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Assign to unlock Business servers",
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_businessPlans.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 16),
          LiquidGlassContainer(
            borderRadius: BorderRadius.circular(14),
            opacity: 0.05,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BusinessPlan>(
                value: _selectedBusinessPlan,
                dropdownColor: const Color(0xFF2C2C2E),
                icon: const Icon(
                  Iconsax.arrow_down_1,
                  color: Colors.white54,
                  size: 20,
                ),
                isExpanded: true,
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 15,
                ),
                items: _businessPlans
                    .map(
                      (bp) => DropdownMenuItem(
                        value: bp,
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.briefcase,
                              size: 18,
                              color: orangeAccent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bp.planName,
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              "${NumberFormat('#,##0').format(bp.price)} cr",
                              style: GoogleFonts.spaceMono(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (bp) => setState(() => _selectedBusinessPlan = bp),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ScaleButton(
            onTap: _businessLoading ? null : _assignBusinessPlan,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    orangeAccent.withOpacity(0.2),
                    orangeAccent.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: orangeAccent.withOpacity(0.4)),
              ),
              child: _businessLoading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: orangeAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.briefcase, color: orangeAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Assign Business Plan",
                          style: GoogleFonts.ibmPlexSans(
                            color: orangeAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
        if (_businessPlans.isEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.info_circle,
                  size: 16,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "No business plans available",
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "CHANGE PASSWORD (OPTIONAL)",
              style: GoogleFonts.exo2(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(16),
          opacity: 0.05,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Enter new password",
              hintStyle: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.3),
              ),
              icon: const Icon(Iconsax.lock, color: Colors.white54, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterInput({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(16),
          opacity: 0.05,
          child: Container(
            height: 60,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                ScaleButton(
                  onTap: () {
                    int val = int.tryParse(controller.text) ?? 0;
                    if (val > 0) {
                      controller.text = '${val - 1}';
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: Icon(
                      Iconsax.minus,
                      size: 16,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.06),
                ),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.spaceMono(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "0",
                      hintStyle: GoogleFonts.spaceMono(
                        color: Colors.white.withOpacity(0.15),
                      ),
                      contentPadding: const EdgeInsets.only(bottom: 4),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.06),
                ),
                ScaleButton(
                  onTap: () {
                    int val = int.tryParse(controller.text) ?? 0;
                    controller.text = '${val + 1}';
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    width: 44,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Icon(
                      Iconsax.add,
                      size: 16,
                      color: AppColors.accentGreen.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.35),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) displayText,
    required IconData icon,
    Color? iconColor,
  }) {
    final accent = iconColor ?? AppColors.accentGreen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.exo2(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(16),
          opacity: 0.05,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: const Color(0xFF2C2C2E),
              icon: const Icon(
                Iconsax.arrow_down_1,
                color: Colors.white54,
                size: 20,
              ),
              isExpanded: true,
              style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: iconColor ?? AppColors.accentGreen,
                          ),
                          const SizedBox(width: 12),
                          Text(displayText(item)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
