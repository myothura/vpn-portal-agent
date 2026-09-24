// lib/core/navigation/app_transitions.dart
import 'package:flutter/material.dart';

/// Page transitions used across the app.
///
/// The default MaterialPageRoute slides up from the bottom on Android, which
/// implies the new screen is a sheet stacked over the old one. That reads
/// wrong for a login handing off to the dashboard: the two are not in a
/// hierarchy, one replaces the other outright.
class AppTransitions {
  /// Fade-through: the outgoing screen fades and shrinks very slightly, the
  /// incoming one fades up from 92%. Material's pattern for a switch between
  /// screens with no parent-child relationship.
  static Route<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, secondary, child) {
        // Incoming content is held back until the outgoing has mostly gone,
        // so the two never cross-dissolve into a muddy overlap.
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
        );
        final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
          ),
        );

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  /// Standard horizontal slide for pushing a detail screen onto a list —
  /// where there IS a hierarchy and the back gesture should feel like
  /// retracing a step.
  static Route<T> slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
