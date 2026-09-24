// lib/shared_widgets/theme_helpers.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- Particle System ---
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
      if (particle.position.dx < 0)
        particle.position = Offset(size.width, particle.position.dy);
      if (particle.position.dx > size.width)
        particle.position = Offset(0, particle.position.dy);
      if (particle.position.dy < 0)
        particle.position = Offset(particle.position.dx, size.height);
      if (particle.position.dy > size.height)
        particle.position = Offset(particle.position.dx, 0);
      paint.color = particle.color;
      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Fade In Up Animation ---
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
