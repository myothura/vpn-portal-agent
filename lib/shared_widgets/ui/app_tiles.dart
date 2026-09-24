// lib/shared_widgets/ui/app_tiles.dart
import 'package:flutter/material.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

/// One entry in a metric row: a number, its label, and a coloured icon.
///
/// [emphasis] marks the figure the agent should act on. Previously every stat
/// card had identical weight, so "Expiring Soon" — the one that costs money
/// if missed — read the same as "Total Users".
class AppStatTile extends StatelessWidget {
  final String label;

  /// Numeric so the tile can count between values. Stats are always counts.
  final int value;
  final IconData icon;
  final Color color;
  final Color wash;
  final VoidCallback? onTap;
  final bool emphasis;

  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.wash,
    this.onTap,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: AppTheme.radiusMd,
      tone: emphasis ? SurfaceTone.wash : SurfaceTone.plain,
      washColor: emphasis ? wash : null,
      // Only the tile that wants attention is textured. On all four it would
      // read as noise and the emphasis would be lost.
      texture: emphasis ? CardTexture.dots : CardTexture.none,
      textureColor: emphasis ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: icon,
                color: color,
                background: emphasis ? AppColors.surface : wash,
                size: 16,
                padding: 7,
                radius: 9,
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppAnimatedNumber(
            value: value,
            style: t.headlineMedium?.copyWith(
              color: emphasis ? color : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: t.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

/// A navigation shortcut. Square-ish so a set of them tiles evenly in a grid
/// regardless of how many the agent's permissions allow.
class AppActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color wash;
  final VoidCallback onTap;
  final int badgeCount;
  final bool busy;

  const AppActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.wash,
    required this.onTap,
    this.badgeCount = 0,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      radius: AppTheme.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Loading stays inside the tile that was tapped. The old
                // full-screen overlay hid the whole dashboard for one action.
                busy
                    ? const SizedBox(
                        width: 34,
                        height: 34,
                        child: Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : AppIconBadge(
                        icon: icon,
                        color: color,
                        background: wash,
                        size: 18,
                        padding: 8,
                        radius: 10,
                      ),
                if (badgeCount > 0 && !busy)
                  Positioned(
                    top: -4,
                    left: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width banner for the single most important thing on screen right now:
/// pending renewals, or an all-clear when there are none.
class AppStatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color wash;
  final VoidCallback? onTap;
  final String? trailingLabel;

  /// Optional artwork behind the banner, aligned right and faded.
  ///
  /// The banner is a wash of one colour across the full width, and the message
  /// only ever fills the left of it. The illustration occupies the space the
  /// text does not, at an opacity low enough that the text above stays the
  /// thing being read.
  final String? backdropAsset;

  const AppStatusBanner({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    required this.wash,
    this.onTap,
    this.trailingLabel,
    this.backdropAsset,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // With artwork, the card goes plain: a coloured wash and a glow behind an
    // illustration that carries its own palette gives two backgrounds fighting
    // for the same space.
    final hasArt = backdropAsset != null;

    return AppCard(
      onTap: onTap,
      tone: hasArt ? SurfaceTone.plain : SurfaceTone.wash,
      washColor: wash,
      showShadow: false,
      texture: hasArt ? CardTexture.none : CardTexture.glow,
      textureColor: color,
      // Square when it carries artwork: the illustration runs to the edge, and
      // a rounded corner cropping it reads as the image being cut rather than
      // as a card shape.
      radius: hasArt ? 0 : AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        children: [
          if (backdropAsset != null)
            Positioned.fill(
              // IMG_L_BANNER_ART — the banner's artwork, decoded at the size
              // it is painted at.
              //
              // The asset name is chosen on the dashboard but the decoding
              // happens here, so this is where cacheWidth belongs. Without it
              // the engine decoded the whole file: expiring_hero.png is
              // 1000x429, which is 1.6 MB held in the image cache to paint a
              // strip narrower than a thumb.
              //
              // The Stack this fills sizes itself to the Row beside it, so the
              // box is about 34 points tall, and an Image given neither width
              // nor height fits itself inside its constraints preserving the
              // aspect ratio — which makes the painted width the box's height
              // times the artwork's aspect, not the width of the screen.
              // Bounded at 3:1, wider than any hero in assets/ (requests_hero
              // is the widest at 2.33:1), so the decode is never under what is
              // drawn, and capped at the banner's own width in case a tall
              // asset is ever passed.
              //
              // Rounded up to a multiple of 64 so a rotation or a text-scale
              // change lands on the same cache key rather than decoding a
              // second copy beside the first.
              child: IgnorePointer(
                // RepaintBoundary: the ShaderMask below is a saveLayer, and
                // this banner sits in a scrolling list with an entrance
                // animation running over it. Its own layer keeps the masked
                // image out of the surrounding repaints.
                child: RepaintBoundary(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final media = MediaQuery.of(context);
                      final maxWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : media.size.width;
                      final slot = constraints.maxHeight.isFinite
                          ? constraints.maxHeight * 3
                          : maxWidth;
                      final painted = slot < maxWidth ? slot : maxWidth;
                      final px = (painted * media.devicePixelRatio).ceil();
                      final cacheWidth = px < 64
                          ? 64
                          : ((px + 63) ~/ 64) * 64;

                      return ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              // Faded in from the left so it never reaches the
                              // text.
                              stops: [0.0, 0.45, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black26,
                                Colors.black,
                              ],
                            ).createShader(rect),
                            blendMode: BlendMode.dstIn,
                            child: Opacity(
                              // Full strength: on the all-clear the banner
                              // carries one short line and the artwork is the
                              // rest of it.
                              opacity: 1.0,
                              child: Image.asset(
                                backdropAsset!,
                                cacheWidth: cacheWidth,
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Row(
            children: [
              // Solid disc rather than a bare glyph: on a wash background a
              // same-hue icon has almost no contrast and the banner reads as a
              // block of colour instead of an alert.
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: AppColors.textOnAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              if (trailingLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingLabel!,
                  style: t.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
