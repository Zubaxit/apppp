import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../state/saved_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../screens/article_detail_screen.dart' show LinkLauncherShare;

/// Bookmark toggle with a jelly pop.
///
/// The press itself compresses the button (spring), the mark swaps from outline
/// to solid with its own overshoot, the colour moves to the accent and a light
/// haptic confirms. Reduced motion keeps the state change and drops the pop.
class BookmarkAction extends StatefulWidget {
  const BookmarkAction({
    super.key,
    required this.article,
    this.size = 20,
    this.dense = false,
    this.showSnack = true,
    this.onDark = false,
    this.onSurface = true,
  });

  final Article article;
  final double size;
  final bool dense;
  final bool showSnack;

  /// Renders a light glass disc for placement over a photograph.
  final bool onDark;

  /// Whether the button draws its own glass disc behind the icon.
  final bool onSurface;

  @override
  State<BookmarkAction> createState() => _BookmarkActionState();
}

class _BookmarkActionState extends State<BookmarkAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    // Eager creation keeps dispose() off the ticker provider.
    _pop = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _bounce() {
    if (!mounted) return;
    if (Motion.of(context).reduce) return;
    _pop.value = 0.78;
    _pop.animateWith(
      SpringSimulation(Springs.release, 0.78, 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SavedController savedController = context.watch<SavedController>();
    final bool saved = savedController.isSaved(widget.article.id);
    final Motion motion = Motion.of(context);
    final Color idle = widget.onDark
        ? Colors.white
        : context.colors.onSurfaceVariant;
    final Color active = widget.onDark ? Colors.white : context.colors.primary;

    final Widget mark = AnimatedSwitcher(
      duration: motion.tap,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        if (motion.reduce) return child;
        return ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        key: ValueKey<bool>(saved),
        size: widget.size,
        color: saved ? active : idle,
      ),
    );

    final Widget disc = widget.onSurface
        ? SizedBox(
            width: widget.dense ? 32 : 38,
            height: widget.dense ? 32 : 38,
            child: GlassPanel(
              radius: Tokens.radiusPill,
              blur: widget.onDark ? Tokens.blurSoft : 0,
              tone: widget.onDark
                  ? GlassTone.subtle
                  : (saved ? GlassTone.selected : GlassTone.raised),
              shadow: false,
              padding: EdgeInsets.zero,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (BuildContext context, Widget? child) =>
                      Transform.scale(scale: _pop.value, child: child),
                  child: mark,
                ),
              ),
            ),
          )
        : SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AnimatedBuilder(
                animation: _pop,
                builder: (BuildContext context, Widget? child) =>
                    Transform.scale(scale: _pop.value, child: child),
                child: mark,
              ),
            ),
          );

    return Semantics(
      button: true,
      label: saved ? context.strings.removeSaved : context.strings.save,
      child: JellySurface(
        onTap: () async {
          unawaited(Haptics.confirm());
          _bounce();
          final bool nowSaved = await savedController.toggle(widget.article);
          if (!widget.showSnack || !context.mounted) return;
          context.showSnack(
            nowSaved ? context.strings.savedLabel : context.strings.removeSaved,
          );
        },
        scale: 0.9,
        child: disc,
      ),
    );
  }
}

/// Share sheet action. Shares the original link, never a copy of the story.
class ShareAction extends StatelessWidget {
  const ShareAction({
    super.key,
    required this.article,
    this.size = 20,
    this.dense = false,
    this.onDark = false,
    this.onSurface = true,
  });

  final Article article;
  final double size;
  final bool dense;
  final bool onDark;
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final Color color = onDark ? Colors.white : context.colors.onSurfaceVariant;
    final Widget icon = Icon(Icons.ios_share_rounded, size: size, color: color);
    return Semantics(
      button: true,
      label: context.strings.share,
      child: JellySurface(
        onTap: () => LinkLauncherShare.shareArticle(context, article),
        scale: 0.9,
        child: onSurface
            ? SizedBox(
                width: dense ? 32 : 38,
                height: dense ? 32 : 38,
                child: GlassPanel(
                  radius: Tokens.radiusPill,
                  blur: onDark ? Tokens.blurSoft : 0,
                  tone: onDark ? GlassTone.subtle : GlassTone.raised,
                  shadow: false,
                  child: Center(child: icon),
                ),
              )
            : SizedBox(width: 40, height: 40, child: Center(child: icon)),
      ),
    );
  }
}

/// A round glass icon button used by toolbars and the masthead.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.badge = false,
    this.size = 18,
    this.diameter = 38,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool badge;
  final double size;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: JellySurface(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: GlassPanel(
            radius: Tokens.radiusPill,
            blur: Tokens.blurSoft,
            shadow: false,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Icon(icon, size: size, color: context.colors.onSurface),
                  if (badge)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin reading-progress rule pinned under the toolbar.
class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({super.key, required this.progress, this.height = 2.5});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double value = progress.clamp(0.0, 1.0);
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              width: constraints.maxWidth * value,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[context.colors.primary, Tokens.accentSoft],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small ink dot, for inline metadata.
class InkDot extends StatelessWidget {
  const InkDot({super.key, this.color, this.size = 3});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? context.colors.onSurfaceVariant.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A hairline that fades out at its ends (kept for older call sites).
class FadingRule extends StatelessWidget {
  const FadingRule({super.key, this.height = 0.9, this.inset = Tokens.gutter});

  final double height;
  final double inset;

  @override
  Widget build(BuildContext context) => SoftRule(inset: inset, thickness: height);
}

/// A translucent label chip drawn over photography ("ব্রেকিং", source name).
class GlassTag extends StatelessWidget {
  const GlassTag({
    super.key,
    required this.label,
    this.color,
    this.blur = Tokens.blurSoft,
  });

  final String label;
  final Color? color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final Color fg = color ?? context.colors.onSurface;
    return GlassPanel(
      tone: GlassTone.subtle,
      blur: blur,
      radius: Tokens.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      shadow: false,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: Tokens.sans,
          fontSize: 9,
          height: 1.2,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
