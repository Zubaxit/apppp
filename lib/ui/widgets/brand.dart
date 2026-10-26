import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../theme/tokens.dart';

/// The Amar News mark, drawn as vector shapes rather than an image asset.
///
/// A front page with a folded corner: warm-white sheet, one printed-red masthead
/// rule, three ink text lines, a red inner fold. It is the same design as the
/// launcher icon and the Android splash, which are both derived from the single
/// master artwork `assets/brand/icon_master.png` by
/// `scripts/build_launcher_icons.py`. The vector is used in-app because it stays
/// crisp at any size and needs no bitmap; the geometry is intentionally the
/// same, so the icon cannot drift away from the app.
class AmarNewsMark extends StatelessWidget {
  const AmarNewsMark({super.key, this.size = 64, this.tile = true});

  final double size;

  /// Whether to draw the graphite tile behind the sheet.
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final double sheet = size * 0.52;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: tile
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.26),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF232327), Color(0xFF141416)],
              ),
              boxShadow: Tokens.shadow(context),
            )
          : null,
      child: SizedBox(
        width: sheet,
        height: sheet * 1.18,
        child: Stack(
          children: <Widget>[
            // The sheet, with the top-right corner folded away.
            Positioned.fill(
              child: ClipPath(
                clipper: const _FoldedPageClipper(),
                child: ColoredBox(
                  color:
                      dark ? const Color(0xFFEFEEEC) : const Color(0xFFF7F6F4),
                ),
              ),
            ),
            Positioned(
              left: sheet * 0.16,
              top: sheet * 0.14,
              width: sheet * 0.36,
              height: sheet * 0.10,
              child: const ColoredBox(color: Tokens.accent),
            ),
            Positioned(
              left: sheet * 0.16,
              top: sheet * 0.36,
              width: sheet * 0.60,
              height: sheet * 0.07,
              child: ColoredBox(
                  color:
                      dark ? const Color(0xFF3C3C40) : const Color(0xFF3C3C40)),
            ),
            Positioned(
              left: sheet * 0.16,
              top: sheet * 0.50,
              width: sheet * 0.60,
              height: sheet * 0.07,
              child: const ColoredBox(color: Color(0xFF3C3C40)),
            ),
            Positioned(
              left: sheet * 0.16,
              top: sheet * 0.64,
              width: sheet * 0.38,
              height: sheet * 0.07,
              child: const ColoredBox(color: Color(0xFF3C3C40)),
            ),
            Positioned(
              left: sheet * 0.16,
              top: sheet * 0.82,
              width: sheet * 0.60,
              height: sheet * 0.035,
              child: const ColoredBox(color: Tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoldedPageClipper extends CustomClipper<Path> {
  const _FoldedPageClipper();

  @override
  Path getClip(Size size) {
    final double fold = size.width * 0.34;
    return Path()
      ..moveTo(0, size.height * 0.06)
      ..quadraticBezierTo(0, 0, size.width * 0.08, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height * 0.94)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width * 0.92,
        size.height,
      )
      ..lineTo(size.width * 0.08, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height * 0.94)
      ..close();
  }

  @override
  bool shouldReclip(_FoldedPageClipper oldClipper) => false;
}

/// The wordmark: the app name in serif with a red rule above it.
class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    required this.text,
    this.subtitle,
    this.alignment = CrossAxisAlignment.center,
    this.size = 26,
  });

  final String text;
  final String? subtitle;
  final CrossAxisAlignment alignment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        Container(width: 26, height: 3, color: Tokens.accent),
        SizedBox(height: size * 0.32),
        Text(
          text,
          style: context.texts.headlineSmall?.copyWith(
            fontFamily: Tokens.serif,
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: context.texts.labelSmall?.copyWith(
              fontSize: 11.5,
              letterSpacing: 0.6,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// An honest placeholder: a soft block sized like the content it replaces.
///
/// No shimmer loop by default — a static tint costs nothing, and a repeating
/// animation on a list of twenty rows drains battery for no information. The
/// slow pulse is opt-in and disabled when motion is reduced.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 2,
    this.pulse = false,
  });

  final double height;
  final double? width;
  final double radius;
  final bool pulse;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.pulse && !reduce && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.onSurface.withValues(alpha: 0.055);
    final Color bright = context.colors.onSurface.withValues(alpha: 0.09);
    final Widget block = DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: SizedBox(height: widget.height, width: widget.width),
    );
    final AnimationController? controller = _controller;
    if (controller == null) return block;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(base, bright, controller.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: child,
        );
      },
      child: SizedBox(height: widget.height, width: widget.width),
    );
  }
}
