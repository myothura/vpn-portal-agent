import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/features/dashboard/services/dashboard_service.dart';
import 'package:vpn_agent_app/features/users/models/plan_model.dart';
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

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});
  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _monthsController = TextEditingController(text: '1');
  final _daysController = TextEditingController(text: '0');

  final _userService = UserManagementService();
  final _dashboardService = DashboardService();

  List<Plan> _plans = [];
  Plan? _selectedPlan;

  List<BusinessPlan> _businessPlans = [];
  BusinessPlan? _selectedBusinessPlan;
  bool _enableBusiness = false;

  bool _isLoading = false;
  bool _isFetchingData = true;
  bool _isPasswordObscured = true;
  String? _currentCreditBalance;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchInitialData();
    _monthsController.addListener(() => setState(() {}));
    _daysController.addListener(() => setState(() {}));
    _usernameController.addListener(() => setState(() {}));
  }

  void _initAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _monthsController.dispose();
    _daysController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isFetchingData = true);
    try {
      final results = await Future.wait([
        _userService.getAvailablePlans(),
        _dashboardService.getDashboardStats(),
        _userService.getBusinessPlans(),
      ]);

      if (mounted) {
        final fetchedPlans = results[0] as List<Plan>;
        _plans = fetchedPlans;
        if (_plans.isNotEmpty) {
          _selectedPlan = _plans.first;
        }

        final stats = results[1];
        if (stats != null && stats is DashboardStats) {
          _currentCreditBalance = stats.formattedCreditBalance;
        }

        _businessPlans = results[2] as List<BusinessPlan>;
        if (_businessPlans.isNotEmpty) {
          _selectedBusinessPlan = _businessPlans.first;
        }
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    } finally {
      if (mounted) setState(() => _isFetchingData = false);
    }
  }

  void _generateRandomPassword() {
    HapticFeedback.lightImpact();
    const length = 8;
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final String password = String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );

    _passwordController.text = password;
    setState(() => _isPasswordObscured = false);
  }

  Future<void> _createUser() async {
    HapticFeedback.mediumImpact();
    if (_formKey.currentState!.validate() && _selectedPlan != null) {
      setState(() => _isLoading = true);

      final months = int.tryParse(_monthsController.text) ?? 0;
      final days = int.tryParse(_daysController.text) ?? 0;

      final success = await _userService.createUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        planId: _selectedPlan!.id,
        months: months,
        days: days,
      );

      if (mounted) {
        if (success) {
          if (_enableBusiness && _selectedBusinessPlan != null) {
            await _assignBusinessAfterCreate();
          }
          setState(() => _isLoading = false);
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _enableBusiness
                    ? 'User created with Business Plan!'
                    : 'User created successfully!',
              ),
              backgroundColor: _enableBusiness
                  ? const Color(0xFFF97316)
                  : AppColors.accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to create user. Check balance or username.',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _assignBusinessAfterCreate() async {
    try {
      final usersResponse = await _userService.getVpnUsers(
        search: _usernameController.text.trim(),
      );
      if (usersResponse != null && usersResponse.users.isNotEmpty) {
        final newUser = usersResponse.users.firstWhere(
          (u) => u.username == _usernameController.text.trim(),
          orElse: () => usersResponse.users.first,
        );
        await _userService.assignBusinessPlan(
          newUser.id,
          _selectedBusinessPlan!.id,
        );
      }
    } catch (e) {
      debugPrint("Business Plan assign after create failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    int months = int.tryParse(_monthsController.text) ?? 0;
    int days = int.tryParse(_daysController.text) ?? 0;
    int basePlanPrice = _selectedPlan?.price ?? 0;
    int chargePrice = (_enableBusiness && _selectedBusinessPlan != null)
        ? _selectedBusinessPlan!.price
        : basePlanPrice;
    double dailyRate = chargePrice / 30;
    int totalDays = (months * 30) + days;
    int totalCost = (dailyRate * totalDays).ceil();

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
            "New User",
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
              child: _isFetchingData
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
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      _buildCreditBalanceCard(),
                                      const SizedBox(height: 32),
                                      _buildGlassTextField(
                                        controller: _usernameController,
                                        label: 'USERNAME',
                                        hint: 'Enter username',
                                        icon: Iconsax.user,
                                        validator: (value) => value!.isEmpty
                                            ? 'Username is required'
                                            : null,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildGlassTextField(
                                        controller: _passwordController,
                                        label: 'PASSWORD',
                                        hint: 'Enter or generate',
                                        icon: Iconsax.lock,
                                        isPassword: true,
                                        showGenerate: true,
                                        validator: (value) => value!.length < 6
                                            ? 'Min 6 chars required'
                                            : null,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildPlanDropdown(),
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
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              "DURATION",
                                              style: GoogleFonts.exo2(
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
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
                                      if (_businessPlans.isNotEmpty) ...[
                                        const SizedBox(height: 28),
                                        _buildBusinessPlanSection(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (!_isFetchingData && !isKeyboardOpen)
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
                            _enableBusiness ? "BUSINESS PLAN" : "TOTAL COST",
                            style: GoogleFonts.exo2(
                              color: _enableBusiness
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
                              if (_enableBusiness) ...[
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
                        onTap: _isLoading ? null : _createUser,
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
                                      Iconsax.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Create",
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
              "BUSINESS PLAN (OPTIONAL)",
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
        ScaleButton(
          onTap: () {
            setState(() {
              _enableBusiness = !_enableBusiness;
            });
            HapticFeedback.lightImpact();
          },
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(14),
            opacity: _enableBusiness ? 0.08 : 0.04,
            tintColor: _enableBusiness ? orangeAccent : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _enableBusiness
                        ? orangeAccent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Iconsax.briefcase,
                    color: _enableBusiness
                        ? orangeAccent
                        : Colors.white.withOpacity(0.3),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Include Business Plan",
                        style: GoogleFonts.exo2(
                          color: _enableBusiness
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Unlock Business servers on creation",
                        style: GoogleFonts.ibmPlexSans(
                          color: _enableBusiness
                              ? orangeAccent.withOpacity(0.7)
                              : Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _enableBusiness
                        ? orangeAccent
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: _enableBusiness
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _enableBusiness
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _enableBusiness
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(14),
                    opacity: 0.05,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                        onChanged: (bp) =>
                            setState(() => _selectedBusinessPlan = bp),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCreditBalanceCard() {
    final username = _usernameController.text.trim();
    final hasUsername = username.isNotEmpty;

    return LiquidGlassContainer(
      opacity: 0.1,
      tintColor: AppColors.accentGreen,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      withBorder: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.wallet_2,
              color: AppColors.accentGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Available Balance",
                  style: GoogleFonts.ibmPlexSans(
                    color: AppColors.accentGreen.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentCreditBalance ?? "...",
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (hasUsername)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGreen.withOpacity(0.25),
                    Colors.blueAccent.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: AppColors.accentGreen.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Text(
                  username[0].toUpperCase(),
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool showGenerate = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(16),
          opacity: 0.05,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && _isPasswordObscured,
            style: GoogleFonts.spaceMono(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            validator: validator,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
              suffixIcon: isPassword
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showGenerate)
                          IconButton(
                            icon: const Icon(
                              Iconsax.magic_star,
                              color: AppColors.accentGreen,
                              size: 20,
                            ),
                            onPressed: _generateRandomPassword,
                            tooltip: "Generate Password",
                          ),
                        IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Iconsax.eye_slash
                                : Iconsax.eye,
                            color: Colors.white.withOpacity(0.4),
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordObscured = !_isPasswordObscured,
                          ),
                        ),
                      ],
                    )
                  : null,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.2),
                fontWeight: FontWeight.normal,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              "PLAN",
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
            child: DropdownButton<Plan>(
              value: _selectedPlan,
              dropdownColor: const Color(0xFF2C2C2E),
              icon: const Icon(
                Iconsax.arrow_down_1,
                color: Colors.white54,
                size: 20,
              ),
              isExpanded: true,
              style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 16),
              items: _plans.map((Plan item) {
                final name = item.planName.toLowerCase();
                Color dotColor = AppColors.accentGreen;
                if (name.contains('gold')) dotColor = const Color(0xFFFFD700);
                if (name.contains('vip') || name.contains('premium'))
                  dotColor = const Color(0xFFBF5AF2);
                if (name.contains('silver') || name.contains('basic'))
                  dotColor = const Color(0xFFACCEF7);
                if (name.contains('private'))
                  dotColor = const Color(0xFFFF2D55);

                return DropdownMenuItem<Plan>(
                  value: item,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dotColor.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.planName,
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${NumberFormat('#,##0').format(item.price)} cr",
                          style: GoogleFonts.spaceMono(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (plan) => setState(() => _selectedPlan = plan),
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
}
