import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Design tokens for the editorial reading experience.
///
/// Everything visual in the app resolves to a value in this file: colour,
/// spacing, radii, typography, elevation and motion. Screens never invent raw
/// numbers, which is what keeps the product feeling composed rather than
/// assembled.
class Tokens {
  const Tokens._();

  // ---------------------------------------------------------------- colour
  /// Warm newsprint ivory — the app's paper.
  static const Color paper = Color(0xFFFAF6EE);
  static const Color paperRaised = Color(0xFFFFFCF6);
  static const Color paperSunken = Color(0xFFF2ECE0);

  /// Ink, not black: a warm near-neutral that reads well on ivory.
  static const Color ink = Color(0xFF1A1815);
  static const Color inkMuted = Color(0xFF5C564D);
  static const Color inkFaint = Color(0xFF8E877B);

  /// A single restrained accent: deep bottle green.
  static const Color green = Color(0xFF0E4A3A);
  static const Color greenSoft = Color(0xFF2A6B57);
  static const Color greenTint = Color(0xFFE6EEE8);

  /// Reserved for breaking news and destructive actions only.
  static const Color signal = Color(0xFFB3261E);

  static const Color hairline = Color(0xFFE6DECD);
  static const Color hairlineStrong = Color(0xFFD6CBB5);

  // Night edition
  static const Color nightBg = Color(0xFF0E1211);
  static const Color nightRaised = Color(0xFF161C1A);
  static const Color nightSunken = Color(0xFF0A0E0D);
  static const Color nightInk = Color(0xFFF2EDE3);
  static const Color nightInkMuted = Color(0xFFB9B3A6);
  static const Color nightInkFaint = Color(0xFF8A8579);
  static const Color nightHairline = Color(0xFF2A322E);
  static const Color mint = Color(0xFF67C9A8);

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
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);

  static const Curve easing = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.8, 0.2, 1);

  // -------------------------------------------------------------- elevation
  /// Barely-there shadow: paper lifting off a desk, not a floating card.
  static List<BoxShadow> shadow(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return const <BoxShadow>[];
    return const <BoxShadow>[
      BoxShadow(
        color: Color(0x0A1A1815),
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
    ];
  }
}

/// Frosted material for navigation bars, sheets and floating controls.
///
/// Used sparingly: content stays on paper, only chrome floats.
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? tint;
  final Border? border;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius shaped = borderRadius ?? BorderRadius.circular(radius);
    final Color base = tint ?? (dark ? Tokens.nightRaised : Tokens.paperRaised);
    final double alpha = dark ? 0.72 : 0.78;
    final Color line = border?.top.color ??
        (dark ? Tokens.nightHairline : Tokens.hairline).withValues(alpha: 0.9);

    return ClipRRect(
      borderRadius: shaped,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base.withValues(alpha: alpha),
            borderRadius: shaped,
            border: showBorder ? Border.all(color: line, width: 0.8) : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
