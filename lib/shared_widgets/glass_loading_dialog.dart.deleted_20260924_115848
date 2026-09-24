import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';

class GlassLoadingDialog extends StatefulWidget {
  final String? message;

  const GlassLoadingDialog({super.key, this.message});

  @override
  State<GlassLoadingDialog> createState() => _GlassLoadingDialogState();
}

class _GlassLoadingDialogState extends State<GlassLoadingDialog>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.message ?? 'Processing';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RotationTransition(
                                turns: _rotationController,
                                child: CustomPaint(
                                  painter: _GradientRingPainter(
                                    color: AppColors.accentGreen,
                                    strokeWidth: 2.5,
                                  ),
                                  size: const Size(50, 50),
                                ),
                              ),
                              RotationTransition(
                                turns: ReverseAnimation(_rotationController),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.06),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.85, end: 1.0)
                                    .animate(
                                      CurvedAnimation(
                                        parent: _pulseController,
                                        curve: Curves.easeInOut,
                                      ),
                                    ),
                                child: const Icon(
                                  Iconsax.flash_1,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayText,
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const _AnimatedEllipsis(),
                          ],
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
}

class _AnimatedEllipsis extends StatefulWidget {
  const _AnimatedEllipsis();

  @override
  State<_AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<_AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final count = (_controller.value * 3).floor();
        return SizedBox(
          width: 18,
          child: Text(
            '.' * (count + 1),
            style: GoogleFonts.exo2(
              color: AppColors.accentGreen,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        );
      },
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _GradientRingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.0), color.withOpacity(0.5), color],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      math.pi * 1.6,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
