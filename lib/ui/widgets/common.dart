import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'editorial.dart';
import 'publisher_logo.dart';

/// Network image with disk caching, a soft fade-in and a graceful failure state.
///
/// The placeholder is a pair of very low-contrast greys rather than a spinner:
/// a photograph resolving should feel like ink settling on paper, not like a
/// component loading.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.decodeWidth = 420,
    this.fade = true,
  });

  final String url;
  final BoxFit fit;

  /// Decode target, in logical pixels. Feed photographs are published at
  /// 1200–2000 px; decoding that for a 92 dp thumbnail costs megabytes per row
  /// and shows up as scroll jank and GC pauses. Every call site states the size
  /// it actually paints, and the codec is asked for that size.
  final double decodeWidth;

  /// Large photographs fade in; thumbnails appear at once, because a fade on a
  /// row that is scrolling past is work nobody sees.
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final int memWidth =
        (decodeWidth * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2))
            .round();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: memWidth,
      maxWidthDiskCache: memWidth,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration(milliseconds: fade ? 260 : 0),
      fadeOutDuration: Duration(milliseconds: fade ? 120 : 0),
      placeholder: (BuildContext context, String value) =>
          const NewsImageFallback(),
      errorWidget: (BuildContext context, String value, Object error) =>
          const NewsImageFallback(),
    );
  }
}

/// Offline, fixed-size visual used for missing, loading and failed story art.
/// It is intentionally the same asset in every card, so a failed request cannot
/// create a broken icon or a late layout shift.
class NewsImageFallback extends StatelessWidget {
  const NewsImageFallback({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/news_fallback.jpg',
        fit: BoxFit.cover,
        cacheWidth: 960,
        filterQuality: FilterQuality.low,
      );
}

/// Publication identity: the publisher's own mark on a light tile.
///
/// The tile is the same shape and size it has always been; only its contents
/// changed from a drawn initial to the publisher's real icon. When no icon can
/// be fetched, [PublisherLogo] paints the monogram in that same tile, so the
/// directory never shows a broken image and never invents a logo.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, required this.source, this.size = 44});

  final NewsSource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PublisherLogo(source: source, size: size);
  }
}

/// Section header used across the secondary screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(Tokens.gutter, 22, Tokens.gutter, 10),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: context.texts.titleLarge?.copyWith(
                    fontFamily: Tokens.serif,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (actionLabel != null)
                Pressable(
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      actionLabel!,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: context.texts.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A calm empty state: an icon in a glass disc, a serif line, a body and up to
/// two actions. Never a full-screen illustration.
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
      padding: EdgeInsets.fromLTRB(
        Tokens.gutter,
        compact ? 24 : 56,
        Tokens.gutter,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.16),
                width: 0.9,
              ),
            ),
            child: Icon(icon, size: 21, color: context.colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.texts.titleLarge?.copyWith(
              fontFamily: Tokens.serif,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: context.texts.bodySmall?.copyWith(fontSize: 12.5, height: 1.65),
          ),
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: 18),
            JellyButton(
              label: actionLabel!,
              icon: Icons.refresh_rounded,
              onPressed: onAction,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Honest placeholder block. Pulses only when asked to.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = Tokens.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(height: height, width: width, radius: radius);
  }
}

/// The list skeleton: rows shaped like the real rows, so nothing jumps when the
/// headlines arrive.
class ArticleSkeleton extends StatelessWidget {
  const ArticleSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    // One pulse for every block in the list instead of one ticker per block.
    return ShimmerScope(
      child: ListView(
      // Skeletons are dropped into existing scroll views as well, so they size
      // to their rows instead of demanding a viewport of their own.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 14, Tokens.gutter, 24),
      children: <Widget>[
        const ShimmerBox(height: 132, radius: Tokens.radiusLg),
        const SizedBox(height: 22),
        for (int i = 0; i < count; i++) ...<Widget>[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ShimmerBox(height: 9, width: 70),
                    SizedBox(height: 9),
                    ShimmerBox(height: 15),
                    SizedBox(height: 7),
                    ShimmerBox(height: 15, width: 190),
                  ],
                ),
              ),
              SizedBox(width: 14),
              ShimmerBox(height: 72, width: 72, radius: Tokens.radiusSm),
            ],
          ),
          const SizedBox(height: 18),
          const SoftRule(opacity: 0.7),
          const SizedBox(height: 18),
        ],
      ],
      ),
    );
  }
}

/// Feed health badge: working / failing / unchecked, stated plainly.
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
    } else if (health == null) {
      label = context.strings.feedUnchecked;
      color = context.colors.onSurfaceVariant;
    } else if (health!.isOk) {
      label = context.strings.feedWorking;
      color = Tokens.success;
    } else {
      label = context.strings.feedFailing;
      color = context.colors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.sans,
              fontSize: 9.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Publication metadata line: type · language · location.
String publicationMeta(NewsSource source, {required bool bengali}) {
  final List<String> parts = <String>[
    if (bengali) _typeBn(source.type) else _typeEn(source.type),
    source.language == SourceLanguage.bn
        ? (bengali ? 'বাংলা' : 'Bengali')
        : (bengali ? 'ইংরেজি' : 'English'),
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
