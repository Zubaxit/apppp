import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Design tokens for Amar News.
///
/// The identity is deliberately monochrome: graphite ink and warm paper in the
/// light theme, near-black and light gray in the dark theme, with one deep red
/// carrying every meaningful accent. Nothing in the app invents a raw colour or
/// duration — it resolves through this file.
class Tokens {
  const Tokens._();

  // ---------------------------------------------------------------- colour
  /// Warm newsprint ivory — the app's paper.
  static const Color paper = Color(0xFFF6F4F1);
  static const Color paperRaised = Color(0xFFFFFFFF);
  static const Color paperSunken = Color(0xFFEDEAE5);

  /// Ink, not pure black: warm graphite that reads calmly on paper.
  static const Color ink = Color(0xFF191A1B);
  static const Color inkMuted = Color(0xFF5B5E61);
  static const Color inkFaint = Color(0xFF8C9094);

  /// The single accent: a deep, printed red.
  static const Color accent = Color(0xFFAF1F2B);
  static const Color accentSoft = Color(0xFFC64A52);
  static const Color accentTint = Color(0xFFF8E8E9);

  /// Breaking news uses the accent, kept separate so the semantics stay clear.
  static const Color signal = Color(0xFFC0182A);

  /// Semantic states, used only where they mean something.
  static const Color success = Color(0xFF1F6F4A);
  static const Color warning = Color(0xFF9A6407);
  static const Color danger = Color(0xFFB3261E);

  static const Color hairline = Color(0xFFE3DFD9);
  static const Color hairlineStrong = Color(0xFFD0CBC3);

  /// Translucent fills for frosted chrome.
  static const Color glassLight = Color(0xFFFFFFFF);
  static const Color glassDark = Color(0xFF141416);

  // Night edition
  static const Color nightBg = Color(0xFF0B0B0C);
  static const Color nightRaised = Color(0xFF171719);
  static const Color nightSunken = Color(0xFF070708);
  static const Color nightInk = Color(0xFFF3F2F0);
  static const Color nightInkMuted = Color(0xFFB3B2AF);
  static const Color nightInkFaint = Color(0xFF87868A);
  static const Color nightHairline = Color(0xFF2B2B2E);
  static const Color accentNight = Color(0xFFFF6B73);

  // ------------------------------------------------------------- typography
  static const String serif = 'NotoSerifBengali';
  static const String sans = 'NotoSansBengali';

  /// Editorial scale. Headline sizes are generous because this is a reading
  /// app; body copy stays at a comfortable 15–16.
  static const double displaySize = 34;
  static const double headlineSize = 25;
  static const double titleSize = 19;
  static const double leadSize = 16;
  static const double bodySize = 15;
  static const double captionSize = 12.5;
  static const double labelSize = 11.5;

  // ---------------------------------------------------------------- spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Page gutter. Asymmetric composition starts from a consistent edge.
  static const double gutter = 20;

  // ----------------------------------------------------------------- shapes
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;
  static const double radiusPill = 999;

  // ----------------------------------------------------------------- motion
  /// One motion vocabulary, used by every screen.
  ///
  /// [tap]           immediate feedback under a finger;
  /// [standard]      the default for state changes (chips, tabs, fades);
  /// [emphasized]    entrances and route changes;
  /// [slow]          a single unhurried moment per screen at most.
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 460);

  // Legacy aliases kept so older widgets keep the same rhythm.
  static const Duration fast = tap;
  static const Duration base = standard;

  static const Curve easing = Curves.easeOutCubic;
  static const Curve easeStandard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve easeEmphasized = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve easeExit = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve easeOvershoot = Curves.easeOutBack;

  // Legacy alias.
  static const Curve emphasizedCurve = easeEmphasized;

  // -------------------------------------------------------------- elevation
  /// A soft, low shadow: a printed sheet lifting off a desk, not a floating
  /// card. Glass surfaces get their depth from the border and blur instead.
  static List<BoxShadow> shadow(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return const <BoxShadow>[];
    return const <BoxShadow>[
      BoxShadow(
        color: Color(0x0F191A1B),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Color(0x08000000),
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
    ];
  }
}

/// Frosted material for navigation bars, sheets and floating controls.
///
/// Used sparingly: content stays on paper, only chrome floats. The surface is a
/// real backdrop blur plus a translucent fill and a hairline border, which is
/// what makes it read as glass rather than a tinted rectangle.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 0,
    this.borderRadius,
    this.blur = 24,
    this.tint,
    this.border,
    this.showBorder = true,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? tint;
  final Border? border;
  final bool showBorder;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius shaped = borderRadius ?? BorderRadius.circular(radius);
    final Color base = tint ?? (dark ? Tokens.glassDark : Tokens.glassLight);
    final double alpha = dark ? 0.72 : 0.72;
    final Color line = border?.top.color ??
        (dark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.75));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shaped,
        boxShadow: shadow ? Tokens.shadow(context) : null,
      ),
      child: ClipRRect(
        borderRadius: shaped,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base.withValues(alpha: alpha),
              borderRadius: shaped,
              border: showBorder ? Border.all(color: line, width: 0.9) : null,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
