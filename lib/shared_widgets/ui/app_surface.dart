// lib/shared_widgets/ui/app_surface.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';

/// Opaque card. Replaces LiquidGlassContainer, which was copy-pasted into
/// fifteen screens and wrapped every instance in a BackdropFilter — a
/// full-surface blur per card, repainted on every scroll frame.
///
/// [tone] tints the whole surface for cards that need emphasis (a wash for
/// status, ink for one high-contrast card per screen at most).
enum SurfaceTone { plain, wash, ink }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final SurfaceTone tone;

  /// Fill used when [tone] is wash — pass one of the *Wash tokens.
  final Color? washColor;
  final VoidCallback? onTap;
  final bool showBorder;
  final bool showShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusLg,
    this.tone = SurfaceTone.plain,
    this.washColor,
    this.onTap,
    this.showBorder = true,
    this.showShadow = true,
  });

  Color get _fill => switch (tone) {
        SurfaceTone.plain => AppColors.surface,
        SurfaceTone.wash => washColor ?? AppColors.surfaceAlt,
        SurfaceTone.ink => AppColors.inkSurface,
      };

  Color get _line => switch (tone) {
        SurfaceTone.plain => AppColors.border,
        SurfaceTone.wash => Colors.black.withValues(alpha: 0.06),
        SurfaceTone.ink => Colors.white.withValues(alpha: 0.10),
      };

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: shape,
        border: showBorder ? Border.all(color: _line) : null,
        // Ink cards sit on their own weight; a shadow under them just muddies
        // the edge on a light page.
        boxShadow:
            showShadow && tone != SurfaceTone.ink ? AppTheme.cardShadow : null,
      ),
      child: child,
    );

    if (onTap == null) return card;

    // Material ink ripple rather than a scale animation: it shows WHERE the
    // touch landed, which matters on tiles that sit edge to edge.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: shape,
        child: card,
      ),
    );
  }
}

/// Small square icon plate used inside cards and tiles.
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double padding;
  final double radius;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 20,
    this.padding = 10,
    this.radius = AppTheme.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// Section heading with an optional trailing action, e.g.
/// "Today's Todos            View Details".
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: t.titleMedium),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Status pill — "ACTIVE", "3 pending".
class AppPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool dot;

  const AppPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// The app's only loading indicator. Replaces GlassLoadingIndicator and
/// glass_loading_dialog, both of which blurred what was behind them.
class AppLoader extends StatelessWidget {
  final String? message;
  final bool compact;

  const AppLoader({super.key, this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: compact ? 18 : 26,
      height: compact ? 18 : 26,
      child: const CircularProgressIndicator(strokeWidth: 2.5),
    );

    if (compact || message == null) return Center(child: spinner);

    return Center(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Empty / error state. Every list screen hand-rolled its own; this is the
/// shared one.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconBadge(
              icon: icon,
              color: AppColors.textTertiary,
              background: AppColors.surfaceAlt,
              size: 26,
              padding: 16,
              radius: AppTheme.radiusMd,
            ),
            const SizedBox(height: 16),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: t.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
