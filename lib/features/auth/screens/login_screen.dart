import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⭐️ Import added for HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configs & Widgets
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/l10n/app_localizations.dart';
import 'package:vpn_agent_app/shared_widgets/language_picker_widget.dart';

// Bloc Imports
import 'package:vpn_agent_app/features/auth/bloc/agent_login_bloc.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';

// --- 1. Animation Helpers ---
class FadeInUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const FadeInUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.slideOffset = 0.2,
  });

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

// --- 2. Particle System ---
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
  final double verticalBounds;

  ParticlePainter({
    required this.particles,
    required this.animation,
    this.verticalBounds = 1.0,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final double bottomBoundary = size.height * verticalBounds;

    for (var particle in particles) {
      particle.position += particle.velocity;
      if (particle.position.dx < 0) {
        particle.position = Offset(size.width, particle.position.dy);
      }
      if (particle.position.dx > size.width) {
        particle.position = Offset(0, particle.position.dy);
      }
      if (particle.position.dy < 0) {
        particle.position = Offset(particle.position.dx, bottomBoundary);
      }
      if (particle.position.dy > bottomBoundary) {
        particle.position = Offset(particle.position.dx, 0);
      }
      paint.color = particle.color;
      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- 3. Login Screen (Main Entry) ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AgentLoginBloc(),
      child: const _LoginView(),
    );
  }
}

// --- 4. Login View (UI & Logic) ---
class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;

  late AnimationController _particleController;
  late AnimationController _logoController;
  late Animation<double> _logoScale;

  List<Particle> _particles = [];
  final int _particleCount = 40;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _generateParticles(size);
    });

    _loadUserCredentials();
  }

  void _generateParticles(Size size) {
    _particles = List.generate(_particleCount, (index) {
      return Particle(
        position: Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        color: AppColors.accentGreen.withOpacity(_random.nextDouble() * 0.15),
        radius: _random.nextDouble() * 2.5,
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 0.5,
          (_random.nextDouble() - 0.5) * 0.5,
        ),
      );
    });
    if (mounted) setState(() {});
  }

  Future<void> _loadUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && mounted) {
      setState(() {
        _rememberMe = true;
        _emailController.text = prefs.getString('saved_email') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
      });
    }
  }

  Future<void> _saveUserCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_particleController.isAnimating) _particleController.repeat();
      if (!_logoController.isAnimating) _logoController.repeat(reverse: true);
    } else {
      _particleController.stop();
      _logoController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _particleController.dispose();
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<AgentLoginBloc, AgentLoginState>(
      listener: (context, state) async {
        if (state.status == AgentLoginStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? "Login Failed"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.status == AgentLoginStatus.success) {
          await _saveUserCredentials(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScaffold()),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black],
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
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- Logo (Balanced Size: 90) ---
                          FadeInUp(
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _logoController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _logoScale.value,
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.accentGreen
                                              .withOpacity(0.08),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.accentGreen
                                                .withOpacity(0.08),
                                            border: Border.all(
                                              color: AppColors.accentGreen
                                                  .withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.accentGreen
                                                    .withOpacity(0.15),
                                                blurRadius: 40,
                                                spreadRadius: 5,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Iconsax.shield_tick,
                                            size: 34,
                                            color: AppColors.accentGreen,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            child: Text(
                              "AGENT PORTAL",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.exo2(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 3.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeInUp(
                            delay: const Duration(milliseconds: 300),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Manage your VPN network securely",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          FadeInUp(
                            delay: const Duration(milliseconds: 400),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    "USERNAME",
                                    style: GoogleFonts.exo2(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                _buildGlassTextField(
                                  controller: _emailController,
                                  icon: Iconsax.user,
                                  hint: l10n?.username ?? "Agent Username",
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          FadeInUp(
                            delay: const Duration(milliseconds: 500),
                            child: BlocBuilder<AgentLoginBloc, AgentLoginState>(
                              buildWhen: (prev, curr) =>
                                  prev.isPasswordVisible !=
                                  curr.isPasswordVisible,
                              builder: (context, state) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 8,
                                      ),
                                      child: Text(
                                        "PASSWORD",
                                        style: GoogleFonts.exo2(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    _buildGlassTextField(
                                      controller: _passwordController,
                                      icon: Iconsax.lock,
                                      hint: l10n?.password ?? "Password",
                                      isPassword: !state.isPasswordVisible,
                                      onSuffixTap: () {
                                        context.read<AgentLoginBloc>().add(
                                          AgentLoginPasswordVisibilityToggled(),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          // --- Remember Me ---
                          FadeInUp(
                            delay: const Duration(milliseconds: 600),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _rememberMe = !_rememberMe,
                                      );
                                      HapticFeedback.lightImpact();
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 40,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: _rememberMe
                                                ? AppColors.accentGreen
                                                : Colors.white.withOpacity(
                                                    0.08,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                            border: Border.all(
                                              color: _rememberMe
                                                  ? AppColors.accentGreen
                                                        .withOpacity(0.5)
                                                  : Colors.white.withOpacity(
                                                      0.1,
                                                    ),
                                            ),
                                          ),
                                          child: AnimatedAlign(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            alignment: _rememberMe
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _rememberMe
                                                    ? Colors.white
                                                    : Colors.white.withOpacity(
                                                        0.35,
                                                      ),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          "Remember Me",
                                          style: GoogleFonts.ibmPlexSans(
                                            color: _rememberMe
                                                ? Colors.white.withOpacity(0.8)
                                                : Colors.white.withOpacity(0.4),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // --- Login Button ---
                          FadeInUp(
                            delay: const Duration(milliseconds: 700),
                            child: BlocBuilder<AgentLoginBloc, AgentLoginState>(
                              builder: (context, state) {
                                return _buildGlassLoginButton(
                                  l10n?.login ?? "LOGIN",
                                  state.status == AgentLoginStatus.loading
                                      ? null
                                      : () {
                                          FocusScope.of(context).unfocus();
                                          context.read<AgentLoginBloc>().add(
                                            AgentLoginSubmitted(
                                              email: _emailController.text
                                                  .trim(),
                                              password: _passwordController.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                  isLoading:
                                      state.status == AgentLoginStatus.loading,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Language Picker (Balanced Scale)
                  Positioned(
                    top: 16.0,
                    left: 16.0,
                    child: Transform.scale(
                      scale: 0.85, // Adjusted to 0.85
                      child: const LanguagePickerWidget(),
                    ),
                  ),

                  // ✅ SIGN IN Text (Balanced Font Size)
                  Positioned(
                    top: 24.0,
                    right: 24.0,
                    child: FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.login,
                              size: 14,
                              color: AppColors.accentGreen.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "SIGN IN",
                              style: GoogleFonts.exo2(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ✅ Updated Footer
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: FadeInUp(
                      delay: const Duration(milliseconds: 1000),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.code_1,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Develop By Ghost Developer",
                                  style: GoogleFonts.ibmPlexSans(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "v2.0.0",
                              style: GoogleFonts.spaceMono(
                                color: Colors.white.withOpacity(0.12),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers (Balanced Sizes) ---
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.ibmPlexSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppColors.accentGreen,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.2),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          suffixIcon: onSuffixTap != null
              ? IconButton(
                  icon: Icon(
                    isPassword ? Iconsax.eye_slash : Iconsax.eye,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                  onPressed: onSuffixTap,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGlassLoginButton(
    String text,
    VoidCallback? onPressed, {
    bool isLoading = false,
  }) {
    final bool isEnabled = onPressed != null;

    return GestureDetector(
      onTapDown: (_) {
        if (isEnabled) HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isEnabled
                ? [
                    AppColors.accentGreen.withOpacity(0.25),
                    AppColors.accentGreen.withOpacity(0.08),
                  ]
                : [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.03),
                  ],
          ),
          border: Border.all(
            color: isEnabled
                ? AppColors.accentGreen.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: onPressed,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.login,
                      size: 20,
                      color: isEnabled
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      text.toUpperCase(),
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isEnabled
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
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
