import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';

class AppEffectsScope extends InheritedWidget {
  const AppEffectsScope({
    super.key,
    required this.ultraLight,
    required super.child,
  });

  final bool ultraLight;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppEffectsScope>()
          ?.ultraLight ??
      false;

  @override
  bool updateShouldNotify(AppEffectsScope oldWidget) =>
      oldWidget.ultraLight != ultraLight;
}

/// The backdrop the glass refracts.
///
/// Three enormous, very low-contrast radial blooms on paper (or charcoal). It is
/// painted once inside a [RepaintBoundary] and never animates, so it costs a
/// single layer instead of a running shader. Without something like this a
/// translucent bar just looks grey; with it, the bar picks up a soft gradient
/// as the page scrolls beneath it.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> blooms = dark ? Tokens.auroraDark : Tokens.auroraLight;
    final Color base = dark ? Tokens.nightBg : Tokens.paper;
    if (AppEffectsScope.of(context)) {
      return ColoredBox(
        color: base,
        child: child ?? const SizedBox.expand(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: base),
        RepaintBoundary(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _Bloom(
                  alignment: const Alignment(-0.95, -1.0),
                  color: blooms[0],
                  opacity: dark ? 0.85 : 0.95,
                  size: 0.95,
                ),
                _Bloom(
                  alignment: const Alignment(1.05, -0.55),
                  color: blooms[1],
                  opacity: dark ? 0.75 : 0.85,
                  size: 0.8,
                ),
                _Bloom(
                  alignment: const Alignment(0.2, 1.05),
                  color: blooms[2],
                  opacity: dark ? 0.8 : 0.9,
                  size: 1.0,
                ),
              ],
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.alignment,
    required this.color,
    required this.opacity,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: size,
        heightFactor: size * 0.7,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0.0),
              ],
              stops: const <double>[0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// How much material a [GlassPanel] should show.
enum GlassTone {
  /// Barely there: a wash over content, for image overlays and badges.
  subtle,

  /// The default floating surface: bars, chips, tiles.
  raised,

  /// Accent-tinted, for a selected control.
  selected,

  /// Solid-ish glass for sheets and dialogs that must stay legible.
  sheet,
}

/// A layered translucent surface.
///
/// Real glass needs five things at once, and this widget supplies all of them:
/// a [BackdropFilter] blur, a translucent gradient fill (lighter at the top,
/// so the surface catches light), a hairline border, a 1 px inner sheen along
/// the top edge and a soft outer shadow. The blur is optional: cards that sit
/// on flat paper use [blur] = 0, which is cheaper and reads as frosted paper
/// rather than frozen glass.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = Tokens.radiusMd,
    this.borderRadius,
    this.blur = 0,
    this.tone = GlassTone.raised,
    this.tint,
    this.border = true,
    this.shadow = true,
    this.elevation = 1,
    this.sheen = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BorderRadius? borderRadius;
  final double blur;
  final GlassTone tone;

  /// Overrides the base colour (used for accent-tinted selections).
  final Color? tint;
  final bool border;
  final bool shadow;
  final double elevation;
  final bool sheen;

  /// The fill gradient for a tone, in light or dark.
  LinearGradient _fill(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (tint != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tint!.withValues(alpha: dark ? 0.30 : 0.22),
          tint!.withValues(alpha: dark ? 0.16 : 0.10),
        ],
      );
    }
    switch (tone) {
      case GlassTone.subtle:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const <Color>[Color(0xCC101215), Color(0xCC0A0B0D)]
              : const <Color>[Color(0xE6FFFFFF), Color(0xD9FBFAF8)],
        );
      case GlassTone.selected:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: dark ? 0.26 : 0.16),
            Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: dark ? 0.14 : 0.08),
          ],
        );
      case GlassTone.sheet:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const <Color>[Color(0xF2141619), Color(0xF20C0D0F)]
              : const <Color>[Color(0xFAFFFFFF), Color(0xF7F6F4F1)],
        );
      case GlassTone.raised:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? <Color>[
                  Tokens.glassDark.withValues(alpha: 0.78),
                  Tokens.glassDark.withValues(alpha: 0.60),
                ]
              : <Color>[
                  Tokens.glassLight.withValues(alpha: 0.82),
                  Tokens.paperRaised.withValues(alpha: 0.62),
                ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius shaped = borderRadius ?? BorderRadius.circular(radius);
    final Color edge = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.85);
    final Color line = dark ? Tokens.nightHairline : Tokens.hairline;
    final bool lightEffects = AppEffectsScope.of(context);
    final bool effectiveSheen = sheen && !lightEffects;
    final bool effectiveShadow = shadow && !lightEffects;
    final double effectiveBlur = lightEffects ? 0 : blur;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: _fill(context),
        borderRadius: shaped,
        border: border ? Border.all(color: line, width: 0.9) : null,
      ),
      child: Stack(
        children: <Widget>[
          Padding(padding: padding, child: child),
          if (effectiveSheen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shaped,
                    gradient: LinearGradient(
                      colors: <Color>[edge, edge.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (effectiveBlur > 0) {
      surface = ClipRRect(
        borderRadius: shaped,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: surface,
        ),
      );
    } else {
      surface = ClipRRect(borderRadius: shaped, child: surface);
    }

    if (!effectiveShadow) return surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shaped,
        boxShadow: Tokens.shadow(context, lift: elevation),
      ),
      child: surface,
    );
  }
}

/// A frosted chip used for topics, filters and segmented controls.
///
/// Selection changes colour, border and weight, and the whole chip compresses
/// under a finger through [JellySurface] — the interaction, not the colour
/// alone, is what makes it feel alive.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.trailingCount,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final int? trailingCount;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fg = selected
        ? Theme.of(context).colorScheme.primary
        : (dark ? Tokens.nightInkMuted : Tokens.inkMuted);

    return JellySurface(
      onTap: onTap,
      scale: 0.93,
      onLongPress: null,
      child: AnimatedContainer(
        duration: motion.standard,
        curve: Tokens.easeStandard,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 11 : 14,
          vertical: dense ? 7 : 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
          color: selected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: dark ? 0.20 : 0.11)
              : (dark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.white.withValues(alpha: 0.55)),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.38)
                : (dark ? Tokens.nightHairline : Tokens.hairline),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: dense ? 13 : 15, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tokens.sans,
                  fontSize: dense ? 11.5 : 12.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.1,
                  color: fg,
                ),
              ),
            ),
            if (trailingCount != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '$trailingCount',
                style: TextStyle(
                  fontFamily: Tokens.sans,
                  fontSize: dense ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The editorial paper surface: no glass, no blur, just a sheet with a hairline.
/// Content lives here so text is never filtered or washed out.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.lg),
    this.radius = Tokens.radiusMd,
    this.raised = true,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool raised;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? Tokens.nightRaised : Tokens.paperRaised,
        borderRadius: BorderRadius.circular(radius),
        border: border
            ? Border.all(
                color: dark ? Tokens.nightHairline : Tokens.hairline,
                width: 0.9,
              )
            : null,
        boxShadow: raised ? Tokens.shadow(context, lift: 0.5) : null,
      ),
      child: child,
    );
  }
}

/// A small uppercase label with a red rule: the app's editorial "kicker".
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.color, this.trailing});

  final String label;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 2,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: Tokens.sans,
            fontSize: 10,
            height: 1.3,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
            color: tint,
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// A hairline separator drawn as a gradient so it fades out at both ends.
class SoftRule extends StatelessWidget {
  const SoftRule(
      {super.key, this.inset = 0, this.opacity = 0.9, this.thickness = 0.9});

  final double inset;
  final double opacity;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color line = dark ? Tokens.nightHairline : Tokens.hairline;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Container(
        height: thickness,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              line.withValues(alpha: 0),
              line.withValues(alpha: opacity),
              line.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// A glass toolbar capsule: the floating bars at the top of screens.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.radius = Tokens.radiusLg,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.margin = EdgeInsets.zero,
    this.blur = Tokens.blurBar,
    this.floating = true,
    this.tone = GlassTone.raised,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double blur;
  final bool floating;
  final GlassTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: GlassPanel(
        radius: radius,
        blur: blur,
        tone: tone,
        shadow: floating,
        elevation: floating ? 1 : 0,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Re-export of the shared surface for older call sites.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 0,
    this.borderRadius,
    this.blur = Tokens.blurBar,
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
    return GlassPanel(
      padding: padding,
      radius: radius,
      borderRadius: borderRadius,
      blur: blur,
      tint: tint ?? border?.top.color,
      border: showBorder,
      shadow: shadow,
      child: child,
    );
  }
}
