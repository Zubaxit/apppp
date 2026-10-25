import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'publisher_logo.dart';

/// A hairline rule: the primary structural element of the layout.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0, this.strong = false});

  final double indent;
  final double endIndent;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color color = strong
        ? (dark ? Tokens.nightHairline : Tokens.hairlineStrong)
        : (dark ? Tokens.nightHairline : Tokens.hairline);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: Container(height: 0.9, color: color),
    );
  }
}

/// Small section kicker: a red rule, a label, optional trailing action.
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
        Eyebrow(label),
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
/// Delegates to [JellySurface], so every pressable surface in the app shares one
/// spring-based response and one haptic policy.
class Pressable extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: scale,
      behavior: behavior,
      child: child,
    );
  }
}

/// Publisher identity at a smaller size: the publisher's own mark, or its
/// monogram when no icon can be had. [filled] fills the tile with the accent,
/// which is how the app says "this is the publisher you are reading".
class SourceMark extends StatelessWidget {
  const SourceMark({super.key, required this.source, this.size = 34, this.filled = false});

  final NewsSource source;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return PublisherLogo(
      source: source,
      size: size,
      solid: filled ? context.colors.primary : null,
    );
  }
}

/// Staggered spring entrance, used once per screen and never on scroll.
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.index = 0, this.offset = 16});

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Reveal(index: index, offset: offset, child: child);
  }
}

/// The masthead: the wordmark and the screen's actions, on one line.
///
/// Kept deliberately compact — the reference gives the header a single line so
/// the first story starts high on the screen. The date lives in the feed's
/// freshness line instead of competing up here.
class Masthead extends StatelessWidget {
  const Masthead({super.key, this.trailing, this.subtitle});

  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.strings.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleLarge?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 20,
                  height: 1.2,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
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
    this.onTap,
    this.onDark = false,
  });

  final Article article;
  final NewsSource? source;
  final bool showDot;
  final bool compact;

  /// Optional tap target (usually "open this publisher").
  final VoidCallback? onTap;

  /// Draws the line for placement over a photograph.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String name = source?.localizedName(bengali: bengali) ?? article.sourceId;
    final String? when = BengaliText.relative(article.publishedAt, bengali: bengali);

    final Color nameColor =
        onDark ? Colors.white : context.colors.primary;
    final Color metaColor = onDark
        ? Colors.white.withValues(alpha: 0.72)
        : context.colors.onSurfaceVariant;

    final Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              fontSize: compact ? 10 : 10.6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: nameColor,
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
                color: metaColor.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        Flexible(
          child: Text(
            when ?? context.strings.noPublicationDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              fontSize: compact ? 10 : 10.6,
              color: metaColor,
              fontStyle: when == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
        if (article.breaking) ...<Widget>[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: context.colors.error,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              context.strings.breakingShort,
              style: TextStyle(
                fontFamily: Tokens.sans,
                fontSize: 8,
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

    if (onTap == null) return line;
    return Pressable(onTap: onTap, scale: 0.99, child: line);
  }
}
