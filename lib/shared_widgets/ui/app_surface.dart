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

  /// Secondary, destructive-by-convention action. Kept off the surface so a
  /// list row does not carry a delete control next to its open target.
  final VoidCallback? onLongPress;
  final bool showBorder;
  final bool showShadow;

  /// Decorative pattern painted behind the content. Kept deliberately faint —
  /// it should register as surface quality, not as an image.
  final CardTexture texture;

  /// Ink for the texture. Defaults to the accent on ink cards and to the
  /// wash's own colour elsewhere.
  final Color? textureColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusLg,
    this.tone = SurfaceTone.plain,
    this.washColor,
    this.onTap,
    this.onLongPress,
    this.showBorder = true,
    this.showShadow = true,
    this.texture = CardTexture.none,
    this.textureColor,
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
      decoration: BoxDecoration(
        color: tone == SurfaceTone.ink ? null : _fill,
        // Ink gets a slight vertical lift so a large dark panel does not read
        // as one flat block.
        gradient: tone == SurfaceTone.ink
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.inkSurface, AppColors.ink],
              )
            : null,
        borderRadius: shape,
        border: showBorder ? Border.all(color: _line) : null,
        // Ink cards sit on their own weight; a shadow under them just muddies
        // the edge on a light page.
        boxShadow:
            showShadow && tone != SurfaceTone.ink ? AppTheme.cardShadow : null,
      ),
      child: Stack(
        children: [
          if (texture != CardTexture.none)
            // Clipped so the pattern stops at the corner radius, and wrapped
            // in RepaintBoundary so it is rasterised once instead of being
            // re-painted with the card's content.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: shape,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _TexturePainter(
                      texture: texture,
                      color: textureColor ??
                          (tone == SurfaceTone.ink
                              ? AppColors.accent
                              : AppColors.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (onTap == null && onLongPress == null) return card;

    // Material ink ripple rather than a scale animation: it shows WHERE the
    // touch landed, which matters on tiles that sit edge to edge.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
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

/// Surface patterns. Each is drawn with plain strokes or a gradient shader —
/// no MaskFilter blur, which would cost a saveLayer per card per frame.
enum CardTexture {
  none,

  /// Sparse dot grid. Reads as paper at a glance.
  dots,

  /// Concentric arcs anchored off one corner. Suits large cards.
  rings,

  /// Soft corner light. The cheapest of the four — one radial shader.
  glow,
}

class _TexturePainter extends CustomPainter {
  final CardTexture texture;
  final Color color;

  const _TexturePainter({required this.texture, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    switch (texture) {
      case CardTexture.none:
        return;

      case CardTexture.dots:
        final paint = Paint()..color = color.withValues(alpha: 0.05);
        const step = 14.0;
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 1.1, paint);
          }
        }

      case CardTexture.rings:
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.10);
        // Anchored beyond the top-right corner so only the arcs cross the
        // card and the pattern never sits behind the reading line.
        final centre = Offset(size.width * 0.94, -size.height * 0.15);
        for (var r = size.height * 0.45; r < size.height * 1.7; r += 22) {
          canvas.drawCircle(centre, r, paint);
        }

      case CardTexture.glow:
        final rect = Offset.zero & size;
        final paint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.85, -0.85),
            radius: 1.1,
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ).createShader(rect);
        canvas.drawRect(rect, paint);
    }
  }

  // Nothing here depends on animation or scroll position, so the raster is
  // reused for the life of the card.
  @override
  bool shouldRepaint(_TexturePainter old) =>
      old.texture != texture || old.color != color;
}

/// Placeholder block with a travelling sheen, for use while real content
/// loads. Sized and positioned to match what will replace it, so the layout
/// does not jump when data arrives — which a centred spinner cannot do.
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // The gradient slides across a fixed box rather than the box moving,
          // so nothing is laid out again per frame.
          final t = _c.value * 2 - 1;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + t, 0),
                end: Alignment(1 + t, 0),
                colors: const [
                  AppColors.surfaceAlt,
                  AppColors.border,
                  AppColors.surfaceAlt,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Number that counts from its previous value to its new one.
///
/// The dashboard repolls every 30 seconds and figures used to snap, so a
/// change was indistinguishable from a rebuild. Animating the transition is
/// what makes "this just moved" legible without a badge or a flash.
class AppAnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  /// Formats the interpolated value. Pass the same formatter the static text
  /// would have used, or the number will change shape mid-count.
  final String Function(int)? format;

  const AppAnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Only `end` is set. TweenAnimationBuilder fills `begin` with the
      // previous end on rebuild, so each new figure counts up from the one
      // before it. Setting begin == end (as is easy to do here) silently
      // disables the animation: the tween has nowhere to travel.
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(
          format?.call(n) ?? '$n',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
