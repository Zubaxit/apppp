import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';

/// Network image with disk caching, a calm fade-in and a graceful failure
/// state. Uses [CachedNetworkImageProvider] under a standard [Image] widget so
/// the behaviour stays on stable Flutter APIs.
class RemoteImage extends StatelessWidget {
  const RemoteImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final Color placeholder = context.colors.surfaceContainerHighest;
    return Image(
      image: CachedNetworkImageProvider(url),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (BuildContext context, Widget child, int? frame, bool sync) {
        if (sync || frame != null) return child;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[ColoredBox(color: placeholder), child],
        );
      },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) => ColoredBox(
        color: placeholder,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Publication identity without any unlicensed logo art: a deterministic
/// monogram derived from the publication id.
///
/// The feed is grayscale plus one accent, so the avatar is too: a paper sunken
/// circle with a serif monogram in the accent. No per-publisher palette — eight
/// colours would fight the rest of the interface for attention.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, required this.source, this.size = 44});

  final NewsSource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? Tokens.nightRaised : Tokens.paperSunken,
        shape: BoxShape.circle,
        border: Border.all(
          color: dark ? Tokens.nightHairline : Tokens.hairline,
          width: 0.8,
        ),
      ),
      child: Text(
        source.monogram,
        style: TextStyle(
          fontFamily: Tokens.serif,
          fontSize: size * 0.36,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 12, 10),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.texts.titleLarge?.copyWith(fontSize: 17)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: context.texts.bodySmall),
                  ),
              ],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: context.colors.primary,
              ),
              child: Text(actionLabel ?? strings.viewAll),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: compact ? 52 : 66,
            height: compact ? 52 : 66,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 24 : 30, color: context.colors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.texts.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            body,
            style: context.texts.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Lightweight skeleton pulse used instead of a blocking spinner.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = Motion.of(context).reduce;
    final Color base = context.colors.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = reduce ? 0.4 : 0.25 + _controller.value * 0.35;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class ArticleSkeleton extends StatelessWidget {
  const ArticleSkeleton({super.key, this.count = 4});

  final int count;

  static const Widget _row = Padding(
    padding: EdgeInsets.fromLTRB(20, 10, 20, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonBox(width: 96, height: 10),
              SizedBox(height: 10),
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(width: 240, height: 16),
              SizedBox(height: 12),
              SkeletonBox(width: 180, height: 10),
            ],
          ),
        ),
        SizedBox(width: 14),
        SkeletonBox(width: 88, height: 88, radius: 12),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(children: List<Widget>.filled(count, _row));
  }
}

/// Compact health indicator used in directory rows and detail headers.
class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key, required this.health, this.hasFeed = true});

  final SourceHealth? health;
  final bool hasFeed;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    if (!hasFeed) {
      label = context.strings.feedNotAvailable;
      color = context.colors.onSurfaceVariant;
    } else if (health == null || health!.status == SourceHealthStatus.unknown) {
      label = context.strings.feedUnchecked;
      color = context.colors.onSurfaceVariant;
    } else if (health!.status == SourceHealthStatus.ok) {
      label = context.strings.feedWorking;
      color = context.isDark ? AppColors.redOnDark : AppColors.brandRed;
    } else if (health!.status == SourceHealthStatus.disabled) {
      label = context.strings.feedNotAvailable;
      color = context.colors.onSurfaceVariant;
    } else {
      label = context.strings.feedFailing;
      color = context.colors.error;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: context.texts.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Publication metadata line: type · language · location.
String publicationMeta(NewsSource source, {required bool bengali}) {
  final List<String> parts = <String>[
    if (bengali) _typeBn(source.type) else _typeEn(source.type),
    source.language == SourceLanguage.bn ? (bengali ? 'বাংলা' : 'Bengali') : (bengali ? 'ইংরেজি' : 'English'),
    if (source.district != null) source.district!,
  ];
  return parts.join(' · ');
}

String _typeBn(PublicationType type) {
  switch (type) {
    case PublicationType.dailyNewspaper:
      return 'দৈনিক';
    case PublicationType.onlinePortal:
      return 'অনলাইন';
    case PublicationType.weekly:
      return 'সাপ্তাহিক';
    case PublicationType.magazine:
      return 'ম্যাগাজিন';
    case PublicationType.newsAgency:
      return 'সংবাদ সংস্থা';
    case PublicationType.broadcaster:
      return 'সম্প্রচারমাধ্যম';
    case PublicationType.unknown:
      return 'প্রকাশনা';
  }
}

String _typeEn(PublicationType type) {
  switch (type) {
    case PublicationType.dailyNewspaper:
      return 'Daily';
    case PublicationType.onlinePortal:
      return 'Online';
    case PublicationType.weekly:
      return 'Weekly';
    case PublicationType.magazine:
      return 'Magazine';
    case PublicationType.newsAgency:
      return 'Agency';
    case PublicationType.broadcaster:
      return 'Broadcaster';
    case PublicationType.unknown:
      return 'Publication';
  }
}

/// "৩ ঘণ্টা আগে" or the explicit "publication time not provided" note.
String articleTimeLabel(
  BuildContext context, {
  required DateTime? publishedAt,
  required DateTime fetchedAt,
}) {
  final String? relative = BengaliText.relative(publishedAt, bengali: context.isBengali);
  if (relative != null) return relative;
  return context.strings.noPublicationDate;
}
