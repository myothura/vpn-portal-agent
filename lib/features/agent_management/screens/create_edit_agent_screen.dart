import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/agent_management/models/agent_model.dart';
import 'package:vpn_agent_app/features/agent_management/services/agent_management_service.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';

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

class CreateEditAgentScreen extends StatefulWidget {
  final AgentModel? agent;
  const CreateEditAgentScreen({super.key, this.agent});

  @override
  State<CreateEditAgentScreen> createState() => _CreateEditAgentScreenState();
}

class _CreateEditAgentScreenState extends State<CreateEditAgentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AgentManagementService _service = AgentManagementService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _addCreditController = TextEditingController();

  bool _isActive = true;
  bool _canSendNoti = false;
  bool _canAccessChat = false;
  bool _isAdmin = false;
  bool _isSaving = false;
  bool _obscurePassword = true;

  List<dynamic> _availablePlans = [];
  List<int> _selectedPlanIds = [];
  bool _isLoadingPlans = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
        );

    _loadPlans();
    _loadAdminStatus();

    if (widget.agent != null) {
      _nameController.text = widget.agent!.name;
      _emailController.text = widget.agent!.email;
      _isActive = widget.agent!.status == 'active';
      _canSendNoti = widget.agent!.canSendNotifications;
      _canAccessChat = widget.agent!.canAccessChat;
      _selectedPlanIds = List.from(widget.agent!.planIds);
    }
  }

  Future<void> _loadAdminStatus() async {
    try {
      final profile = await ProfileService().getProfile();
      if (profile != null && mounted) {
        setState(() {
          _isAdmin = profile['id'] == 16;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    final plans = await _service.getPlans();
    if (mounted) {
      setState(() {
        _availablePlans = plans;
        _isLoadingPlans = false;
      });
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _creditController.dispose();
    _addCreditController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'status': _isActive ? 'active' : 'inactive',
      'plans': _selectedPlanIds,
    };

    if (_isAdmin) {
      data['can_send_notifications'] = _canSendNoti;
      data['can_access_chat'] = _canAccessChat;
    }

    if (widget.agent == null) {
      data['email'] = _emailController.text.trim();
      data['password'] = _passwordController.text.trim();
      data['credit_balance'] = int.tryParse(_creditController.text) ?? 0;
      final success = await _service.createAgent(data);
      if (mounted) _handleResult(success, "Agent created successfully!");
    } else {
      if (_passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text.trim();
      }
      if (_addCreditController.text.isNotEmpty) {
        data['add_credit'] = int.tryParse(_addCreditController.text) ?? 0;
      }
      final success = await _service.updateAgent(widget.agent!.id, data);
      if (mounted) _handleResult(success, "Agent updated successfully!");
    }
  }

  void _handleResult(bool success, String message) {
    setState(() => _isSaving = false);
    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Operation failed. Please check inputs."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.agent != null;
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
            isEdit ? "Edit Agent" : "New Agent",
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
              child: _isLoadingPlans
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isEdit) _buildAgentHeader(),
                                      if (isEdit) const SizedBox(height: 28),
                                      _buildSectionLabel(
                                        "ACCOUNT INFO",
                                        Iconsax.user,
                                        Colors.blueAccent,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInputField(
                                        controller: _nameController,
                                        label: "Agent Name",
                                        icon: Iconsax.user,
                                        validator: (v) =>
                                            v!.isEmpty ? "Required" : null,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInputField(
                                        controller: _emailController,
                                        label: "Email Address",
                                        icon: Iconsax.sms,
                                        readOnly: isEdit,
                                        validator: (v) =>
                                            v!.isEmpty || !v.contains('@')
                                            ? "Invalid email"
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInputField(
                                        controller: _passwordController,
                                        label: isEdit
                                            ? "New Password (optional)"
                                            : "Password",
                                        icon: Iconsax.lock,
                                        isPassword: true,
                                        validator: (v) {
                                          if (!isEdit &&
                                              (v == null || v.length < 6))
                                            return "Min 6 chars";
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      _buildSectionLabel(
                                        "CREDITS",
                                        Iconsax.wallet_2,
                                        Colors.orangeAccent,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFinancialSection(isEdit),
                                      const SizedBox(height: 24),
                                      _buildSectionLabel(
                                        "ASSIGNED PLANS",
                                        Iconsax.box,
                                        const Color(0xFFA78BFA),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildPlanGrid(),
                                      const SizedBox(height: 24),
                                      _buildSectionLabel(
                                        "PERMISSIONS",
                                        Iconsax.setting_2,
                                        AppColors.accentGreen,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildToggleTile(
                                              title: "Status",
                                              isActive: _isActive,
                                              icon: _isActive
                                                  ? Iconsax.tick_circle
                                                  : Iconsax.forbidden_2,
                                              color: _isActive
                                                  ? AppColors.accentGreen
                                                  : Colors.redAccent,
                                              onTap: () => setState(
                                                () => _isActive = !_isActive,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (_isAdmin)
                                            Expanded(
                                              child: _buildToggleTile(
                                                title: "Notify",
                                                isActive: _canSendNoti,
                                                icon: _canSendNoti
                                                    ? Iconsax.notification
                                                    : Iconsax.notification_1,
                                                color: _canSendNoti
                                                    ? Colors.orangeAccent
                                                    : Colors.grey,
                                                onTap: () => setState(
                                                  () => _canSendNoti =
                                                      !_canSendNoti,
                                                ),
                                              ),
                                            ),
                                          if (!_isAdmin)
                                            const Expanded(child: SizedBox()),
                                        ],
                                      ),
                                      if (_isAdmin) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildToggleTile(
                                                title: "Chat",
                                                isActive: _canAccessChat,
                                                icon: _canAccessChat
                                                    ? Iconsax.message_text_1
                                                    : Iconsax.message_remove,
                                                color: _canAccessChat
                                                    ? AppColors.accentGreen
                                                    : Colors.grey,
                                                onTap: () => setState(
                                                  () => _canAccessChat =
                                                      !_canAccessChat,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(child: SizedBox()),
                                          ],
                                        ),
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
            if (!_isLoadingPlans && !isKeyboardOpen)
              Positioned(
                left: 24,
                right: 24,
                bottom: 30,
                child: ScaleButton(
                  onTap: _isSaving ? null : _submit,
                  child: LiquidGlassContainer(
                    opacity: 0.2,
                    tintColor: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEdit ? Iconsax.refresh : Iconsax.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isEdit ? "SAVE CHANGES" : "CREATE AGENT",
                                  style: GoogleFonts.exo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentHeader() {
    return LiquidGlassContainer(
      opacity: 0.1,
      tintColor: const Color(0xFFA78BFA),
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFA78BFA).withOpacity(0.3),
                  const Color(0xFF7C3AED).withOpacity(0.15),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFA78BFA).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                widget.agent!.name.isNotEmpty
                    ? widget.agent!.name[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.exo2(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent!.name,
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      opacity: 0.15,
                      tintColor: _isActive
                          ? AppColors.accentGreen
                          : Colors.redAccent,
                      child: Text(
                        _isActive ? "ACTIVE" : "INACTIVE",
                        style: GoogleFonts.ibmPlexSans(
                          color: _isActive
                              ? AppColors.accentGreen
                              : Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Iconsax.wallet_2,
                      size: 12,
                      color: Colors.orangeAccent.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat('#,##0').format(widget.agent!.creditBalance),
                      style: GoogleFonts.spaceMono(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.exo2(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool readOnly = false,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(16),
      opacity: 0.05,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: validator,
        style: GoogleFonts.ibmPlexSans(
          color: readOnly ? Colors.white38 : Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: label,
          hintStyle: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.25),
            fontSize: 14,
          ),
          icon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                    color: Colors.white.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : readOnly
              ? Icon(
                  Iconsax.lock,
                  size: 16,
                  color: Colors.white.withOpacity(0.15),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFinancialSection(bool isEdit) {
    if (isEdit) {
      return LiquidGlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(18),
        opacity: 0.08,
        tintColor: Colors.orangeAccent,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "BALANCE",
                    style: GoogleFonts.exo2(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat('#,##0').format(widget.agent!.creditBalance),
                    style: GoogleFonts.spaceMono(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: Colors.white.withOpacity(0.08),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _buildInputField(
                controller: _addCreditController,
                label: "Top Up Amount",
                icon: Iconsax.add_circle,
                isNumber: true,
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildInputField(
        controller: _creditController,
        label: "Initial Credits",
        icon: Iconsax.wallet_2,
        isNumber: true,
      );
    }
  }

  Widget _buildPlanGrid() {
    if (_isLoadingPlans) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: AppColors.accentGreen),
        ),
      );
    }

    if (_availablePlans.isEmpty) {
      return LiquidGlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(20),
        opacity: 0.04,
        child: Row(
          children: [
            Icon(
              Iconsax.info_circle,
              size: 16,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(width: 10),
            Text(
              "No plans available",
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.7,
      ),
      itemCount: _availablePlans.length,
      itemBuilder: (context, index) {
        final plan = _availablePlans[index];
        final isSelected = _selectedPlanIds.contains(plan['id']);
        final isBusiness =
            plan['is_business'] == true || plan['is_business'] == 1;

        return ScaleButton(
          scaleAmount: 0.95,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedPlanIds.remove(plan['id']);
              } else {
                _selectedPlanIds.add(plan['id']);
              }
            });
          },
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(14),
            opacity: isSelected ? 0.15 : 0.05,
            tintColor: isSelected
                ? (isBusiness ? const Color(0xFFF97316) : AppColors.accentGreen)
                : Colors.white,
            withBorder: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      isSelected
                          ? Iconsax.tick_circle
                          : (isBusiness ? Iconsax.briefcase : Iconsax.box),
                      color: isSelected
                          ? (isBusiness
                                ? const Color(0xFFF97316)
                                : AppColors.accentGreen)
                          : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan['plan_name'] ?? 'Unknown',
                        style: GoogleFonts.ibmPlexSans(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "${NumberFormat('#,##0').format(plan['price_per_month_credits'])} Cr",
                      style: GoogleFonts.spaceMono(
                        color: isSelected
                            ? (isBusiness
                                  ? const Color(0xFFF97316)
                                  : AppColors.accentGreen)
                            : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    if (isBusiness) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "BIZ",
                          style: GoogleFonts.exo2(
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
        );
      },
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool isActive,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        opacity: isActive ? 0.1 : 0.04,
        tintColor: isActive ? color : null,
        withBorder: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isActive ? "ON" : "OFF",
                  style: GoogleFonts.exo2(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
