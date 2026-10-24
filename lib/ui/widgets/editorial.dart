import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// A hairline rule: the primary structural element of the layout.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0, this.strong = false});

  final double indent;
  final double endIndent;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: Container(
        height: 0.8,
        color: strong
            ? (dark ? Tokens.nightHairline : Tokens.hairlineStrong)
            : (dark ? Tokens.nightHairline : Tokens.hairline),
      ),
    );
  }
}

/// Small section kicker: a green square, a label, optional trailing action.
class Kicker extends StatelessWidget {
  const Kicker(this.label, {super.key, this.action, this.onAction, this.trailing});

  final String label;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(width: 10, height: 2.5, color: context.colors.primary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: context.texts.labelSmall?.copyWith(
            fontSize: 10.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: context.colors.primary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
        if (action != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                action!,
                style: context.texts.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tactile press feedback used for text links, rows and icon buttons.
///
/// Scales down very slightly on touch-down. Respects reduced-motion: the
/// scale is skipped and only the tap is registered.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.975,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (!mounted || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !motion.reduce ? widget.scale : 1,
        duration: motion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Publisher identity without a logo: a serif monogram on paper.
class SourceMark extends StatelessWidget {
  const SourceMark({super.key, required this.source, this.size = 34, this.filled = false});

  final NewsSource source;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color bg = filled
        ? context.colors.primary
        : (dark ? Tokens.nightRaised : Tokens.paperSunken);
    final Color fg = filled
        ? context.colors.onPrimary
        : (dark ? Tokens.nightInk : Tokens.green);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: filled
              ? Colors.transparent
              : (dark ? Tokens.nightHairline : Tokens.hairline),
          width: 0.8,
        ),
      ),
      child: Text(
        source.monogram,
        style: TextStyle(
          fontFamily: Tokens.serif,
          fontSize: size * 0.42,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Staggered entrance used once per screen, never on scroll.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.index = 0, this.offset = 14});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    final int delay = (widget.index.clamp(0, 6)) * 45;
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    if (motion.reduce) return widget.child;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: motion.medium,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : Offset(0, widget.offset / 100),
        duration: motion.medium,
        curve: Tokens.emphasized,
        child: widget.child,
      ),
    );
  }
}

/// The masthead: publication name in serif, with the day's dateline.
class Masthead extends StatelessWidget {
  const Masthead({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final String today = BengaliText.dateTime(
      DateTime.now().toUtc(),
      bengali: context.isBengali,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.strings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleLarge?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 19,
                  letterSpacing: -0.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                today,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Frosted bar used for navigation and floating controls.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.radius = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.margin = EdgeInsets.zero,
    this.floating = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final BorderRadius shaped = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: shaped,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (dark ? Tokens.nightRaised : Tokens.paperRaised)
                  .withValues(alpha: dark ? 0.74 : 0.80),
              borderRadius: shaped,
              border: Border.all(
                color: (dark ? Tokens.nightHairline : Tokens.hairline)
                    .withValues(alpha: 0.85),
                width: 0.8,
              ),
              boxShadow: floating ? Tokens.shadow(context) : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Marker shown only when the publisher itself flagged an item as breaking.
class BreakingTag extends StatelessWidget {
  const BreakingTag({super.key});

  @override
  Widget build(BuildContext context) {
    final Color red = context.colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: red.withValues(alpha: context.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: red.withValues(alpha: 0.3), width: 0.7),
      ),
      child: Text(
        context.strings.breakingShort,
        style: context.texts.labelSmall?.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: red,
        ),
      ),
    );
  }
}

/// Source + time attribution line used everywhere an article is shown.
class Attribution extends StatelessWidget {
  const Attribution({
    super.key,
    required this.article,
    this.source,
    this.showDot = true,
    this.compact = false,
  });

  final Article article;
  final NewsSource? source;
  final bool showDot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String name =
        source?.localizedName(bengali: bengali) ?? article.sourceId;
    final String? when = BengaliText.relative(article.publishedAt, bengali: bengali);
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              fontSize: compact ? 10.5 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: context.colors.primary,
            ),
          ),
        ),
        if (showDot)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 2.5,
              height: 2.5,
              decoration: BoxDecoration(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        Text(
          when ?? context.strings.noPublicationDate,
          maxLines: 1,
          style: context.texts.labelSmall?.copyWith(
            fontSize: compact ? 10.5 : 11,
            color: context.colors.onSurfaceVariant,
            fontStyle: when == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        if (article.breaking) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: context.colors.error,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              context.strings.breakingNews.toUpperCase(),
              style: const TextStyle(
                fontSize: 8.5,
                height: 1.3,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
