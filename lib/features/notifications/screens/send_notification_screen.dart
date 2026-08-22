import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/notification_list_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';

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

class Particle {
  Offset position;
  final Color color;
  final double radius;
  final Offset velocity;
  Particle({
    required this.position,
    required this.color,
    required this.radius,
    required this.velocity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Animation<double> animation;

  ParticlePainter({required this.particles, required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var particle in particles) {
      particle.position += particle.velocity;
      if (particle.position.dx < 0) {
        particle.position = Offset(size.width, particle.position.dy);
      }
      if (particle.position.dx > size.width) {
        particle.position = Offset(0, particle.position.dy);
      }
      if (particle.position.dy < 0) {
        particle.position = Offset(particle.position.dx, size.height);
      }
      if (particle.position.dy > size.height) {
        particle.position = Offset(particle.position.dx, 0);
      }
      paint.color = particle.color;
      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();
  final NotificationListService _service = NotificationListService();
  final UserManagementService _userService = UserManagementService();

  bool _isLoading = false;
  bool _isBroadcast = false;

  String? _selectedUserId;
  String? _selectedUserName;
  List<VpnUser> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _debounce;

  late AnimationController _particleController;
  List<Particle> _particles = [];
  final Random _random = Random();

  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutQuart,
          ),
        );
    _entranceController.forward();

    _bodyController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _generateParticles(size);
    });
  }

  void _generateParticles(Size size) {
    _particles = List.generate(40, (index) {
      return Particle(
        position: Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        color: Colors.white.withOpacity(_random.nextDouble() * 0.15),
        radius: _random.nextDouble() * 2.0,
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 0.3,
          (_random.nextDouble() - 0.5) * 0.3,
        ),
      );
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _particleController.dispose();
    _entranceController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final response = await _userService.getVpnUsers(
        page: 1,
        search: query.trim(),
      );
      if (mounted) {
        setState(() {
          _searchResults = response?.users ?? [];
          _showResults = true;
          _isSearching = false;
        });
      }
    });
  }

  void _selectUser(VpnUser user) {
    setState(() {
      _selectedUserId = user.id.toString();
      _selectedUserName = user.username;
      _searchController.text = user.username;
      _showResults = false;
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
  }

  void _clearSelection() {
    setState(() {
      _selectedUserId = null;
      _selectedUserName = null;
      _searchController.clear();
      _searchResults = [];
      _showResults = false;
    });
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isBroadcast && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please search and select a user first"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    String targetId = _isBroadcast ? 'all' : _selectedUserId!;

    bool success = await _service.sendNotificationToUser(
      userId: targetId,
      title: _titleController.text,
      body: _bodyController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  _isBroadcast ? "Sent to ALL Users!" : "Notification Sent!",
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send. Please try again."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _showResults = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            _isBroadcast ? "Broadcast" : "Send Notification",
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
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
        ),
        body: Stack(
          fit: StackFit.expand,
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
            CustomPaint(
              painter: ParticlePainter(
                particles: _particles,
                animation: _particleController,
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: LiquidGlassContainer(
                        borderRadius: BorderRadius.circular(24),
                        padding: const EdgeInsets.all(24),
                        opacity: 0.05,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        (_isBroadcast
                                                ? Colors.orangeAccent
                                                : AppColors.accentGreen)
                                            .withOpacity(0.1),
                                    border: Border.all(
                                      color:
                                          (_isBroadcast
                                                  ? Colors.orangeAccent
                                                  : AppColors.accentGreen)
                                              .withOpacity(0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isBroadcast
                                                    ? Colors.orangeAccent
                                                    : AppColors.accentGreen)
                                                .withOpacity(0.15),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isBroadcast
                                        ? Iconsax.notification
                                        : Iconsax.send_1,
                                    color: _isBroadcast
                                        ? Colors.orangeAccent
                                        : AppColors.accentGreen,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildSectionLabel(
                                "RECIPIENT TYPE",
                                icon: Iconsax.people,
                              ),
                              const SizedBox(height: 10),
                              _buildTypeSelector(),
                              if (_isBroadcast) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withOpacity(
                                      0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orangeAccent.withOpacity(
                                        0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Iconsax.danger,
                                        size: 16,
                                        color: Colors.orangeAccent.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "This will send to ALL active users",
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Colors.orangeAccent
                                                .withOpacity(0.8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: !_isBroadcast
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionLabel(
                                            "SEARCH USER",
                                            icon: Iconsax.search_normal,
                                          ),
                                          const SizedBox(height: 10),
                                          _buildUserSearch(),
                                          const SizedBox(height: 24),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              _buildSectionLabel(
                                "DETAILS",
                                icon: Iconsax.message_text,
                              ),
                              const SizedBox(height: 10),
                              _buildGlassTextField(
                                controller: _titleController,
                                hint: "Subject / Title",
                                icon: Iconsax.text_block,
                              ),
                              const SizedBox(height: 16),
                              _buildGlassTextField(
                                controller: _bodyController,
                                hint: "Type your message content here...",
                                icon: Iconsax.message_text,
                                maxLines: 5,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "${_bodyController.text.length} chars",
                                  style: GoogleFonts.spaceMono(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildSendButton(),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildTypeSelector() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption("Single User", !_isBroadcast, Iconsax.user),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypeOption("All Users", _isBroadcast, Iconsax.people),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String title, bool isSelected, IconData icon) {
    final Color activeColor = title == "All Users"
        ? Colors.orangeAccent
        : AppColors.accentGreen;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isBroadcast = (title == "All Users");
          if (_isBroadcast) _clearSelection();
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: activeColor.withOpacity(0.35))
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : Colors.white.withOpacity(0.3),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.exo2(
                color: isSelected ? activeColor : Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, {Color? accentColor, IconData? icon}) {
    final color = accentColor ?? AppColors.accentGreen;
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
        if (icon != null) ...[
          Icon(icon, size: 14, color: color.withOpacity(0.6)),
          const SizedBox(width: 7),
        ],
        Text(
          text,
          style: GoogleFonts.exo2(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUserSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedUserId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
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
                          _selectedUserName != null &&
                                  _selectedUserName!.isNotEmpty
                              ? _selectedUserName![0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.exo2(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0F0F10),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Iconsax.tick_circle,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedUserName ?? '',
                        style: GoogleFonts.exo2(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Recipient selected",
                        style: GoogleFonts.ibmPlexSans(
                          color: AppColors.accentGreen.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ScaleButton(
                  onTap: _clearSelection,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Iconsax.close_circle,
                      color: Colors.white.withOpacity(0.4),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_selectedUserId == null) ...[
          LiquidGlassContainer(
            opacity: 0.05,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 50,
              child: Row(
                children: [
                  Icon(
                    Iconsax.search_normal,
                    color: Colors.white.withOpacity(0.4),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      cursorColor: AppColors.accentGreen,
                      onChanged: _onSearchChanged,
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          setState(() => _showResults = true);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Type username to search...",
                        hintStyle: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(bottom: 2),
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.accentGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  if (!_isSearching && _searchController.text.isNotEmpty)
                    ScaleButton(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _showResults = false;
                        });
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
          if (_showResults)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: _searchResults.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          "No users found",
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                        indent: 56,
                      ),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _selectUser(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accentGreen.withOpacity(
                                        0.15,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        user.username.isNotEmpty
                                            ? user.username[0].toUpperCase()
                                            : 'U',
                                        style: GoogleFonts.exo2(
                                          color: AppColors.accentGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.username,
                                          style: GoogleFonts.exo2(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.planName ?? 'No Plan',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Colors.white.withOpacity(
                                              0.35,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (user.hasBusinessPlan)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFF97316,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        "BIZ",
                                        style: GoogleFonts.exo2(
                                          color: const Color(0xFFF97316),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.status == 'active'
                                          ? AppColors.accentGreen.withOpacity(
                                              0.12,
                                            )
                                          : Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      user.status == 'active'
                                          ? "Active"
                                          : "Expired",
                                      style: GoogleFonts.ibmPlexSans(
                                        color: user.status == 'active'
                                            ? AppColors.accentGreen
                                            : Colors.redAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ],
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    final Color focusColor = _isBroadcast
        ? Colors.orangeAccent
        : AppColors.accentGreen;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.ibmPlexSans(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: focusColor,
      validator: (value) => value!.isEmpty ? "This field is required" : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSans(
          color: Colors.white.withOpacity(0.25),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: focusColor.withOpacity(0.5)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 12,
            bottom: maxLines > 1 ? (maxLines * 18.0) : 0,
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
        ),
        errorStyle: GoogleFonts.ibmPlexSans(
          color: Colors.redAccent,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final Color btnColor = _isBroadcast
        ? Colors.orangeAccent
        : AppColors.accentGreen;
    final bool canSend = _isBroadcast || _selectedUserId != null;

    return ScaleButton(
      onTap: _isLoading ? null : _handleSend,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canSend
                ? [btnColor.withOpacity(0.8), btnColor]
                : [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: canSend
              ? null
              : Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: canSend
              ? [
                  BoxShadow(
                    color: btnColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: _isLoading
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
                      _isBroadcast ? Iconsax.notification : Iconsax.send_1,
                      color: canSend
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isBroadcast ? "SEND BROADCAST" : "SEND MESSAGE",
                      style: GoogleFonts.exo2(
                        color: canSend
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
