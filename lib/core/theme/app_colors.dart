// File: lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Semantic colour tokens for the agent app (light theme).
///
/// Screens must reference tokens by ROLE (surface, textPrimary, border), never
/// by literal. A hard-coded Color(0xFF...) in a screen is a bug: it cannot
/// follow a theme change and is why the previous dark-only build could not be
/// re-skinned without touching 1,400+ call sites.
class AppColors {
  // ── Brand ──
  /// VPN Portal brand green. Unchanged from the dark build so the two apps
  /// stay visually related.
  static const Color accent = Color(0xFF22C55E);

  /// Darker green for text/icons ON light surfaces. accent at 14pt on white
  /// is about 2.3:1, below the WCAG AA 4.5:1 floor; this is 4.6:1.
  static const Color accentInk = Color(0xFF15803D);

  /// Very light green wash for selected rows and accent-tinted cards.
  static const Color accentWash = Color(0xFFDCFCE7);

  // ── Surfaces ──
  /// App background. Slightly off-white so white cards read as raised
  /// without needing a shadow.
  static const Color background = Color(0xFFF2F3F5);

  /// Card and sheet background.
  static const Color surface = Color(0xFFFFFFFF);

  /// Input fills, disabled tiles, table stripes.
  static const Color surfaceAlt = Color(0xFFE9EBEF);

  // ── Text ──
  static const Color textPrimary = Color(0xFF16181D);
  static const Color textSecondary = Color(0xFF4A5059);
  static const Color textTertiary = Color(0xFF7B828C);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── Lines ──
  static const Color border = Color(0xFFDCDFE4);
  static const Color borderStrong = Color(0xFFCFD3DA);

  // ── Status ──
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0369A1);

  static const Color successWash = Color(0xFFDCFCE7);
  static const Color warningWash = Color(0xFFFEF3C7);
  static const Color dangerWash = Color(0xFFFEE2E2);
  static const Color infoWash = Color(0xFFE0F2FE);

  // ── Category accents ──
  // Used to tell stat/action tiles apart at a glance. Ink variants are for
  // text and icons; wash variants are for the tile behind them.
  static const Color violet = Color(0xFF6D28D9);
  static const Color violetWash = Color(0xFFEDE9FE);
  static const Color orange = Color(0xFFC2410C);
  static const Color orangeWash = Color(0xFFFFEDD5);
  static const Color cyan = Color(0xFF0E7490);
  static const Color cyanWash = Color(0xFFCFFAFE);

  // ── Ink (high-emphasis card on a light page) ──
  // Deep brand green rather than neutral black. This is the largest single
  // element on the dashboard, so a black panel made the app read as generic —
  // the brand colour only appeared on a nav label and one text link.
  static const Color ink = Color(0xFF0A3B22);
  static const Color inkSurface = Color(0xFF125233);
  static const Color textOnInk = Color(0xFFF2FBF5);

  /// Neutral tile accent, for metrics that are context rather than a call to
  /// action. Keeps the palette from competing with the brand green.
  static const Color neutral = Color(0xFF56606E);
  static const Color neutralWash = Color(0xFFEDEFF2);

  // ── Deprecated dark-build aliases ──
  // Kept only so the not-yet-migrated screens still compile. Each screen drops
  // its uses as it is converted; these are removed once the last one lands.
  @Deprecated('Use AppColors.background')
  static const Color darkBackground = background;

  @Deprecated('Use AppColors.textPrimary')
  static const Color darkText = textPrimary;

  @Deprecated('Use AppColors.accent')
  static const Color accentGreen = accent;

  @Deprecated('Use AppColors.warning')
  static const Color pendingOrange = warning;

  @Deprecated('Use AppColors.danger')
  static const Color rejectedRed = danger;
}
