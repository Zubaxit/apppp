import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'actions.dart';
import 'common.dart';
import 'editorial.dart';

/// The front-page lead: a photograph with layered scrims, a glass publisher
/// pill, and a serif headline sitting on the image.
///
/// This is the one place where type and image are allowed to overlap, and it is
/// what gives the page a focal point instead of a stack of equal cards.
class LeadStory extends StatelessWidget {
  const LeadStory({
    super.key,
    required this.article,
    required this.onTap,
    this.source,
    this.onOpenSource,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback onTap;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final String? image = article.imageUrl;
    final double width = MediaQuery.sizeOf(context).width - Tokens.gutter * 2;
    final double height =
        (image != null ? width * 0.94 : width * 0.62).clamp(240.0, 440.0);
    // On a 320 dp phone the card has room for the headline or the excerpt, not
    // both; the headline wins and the excerpt is dropped rather than clipped.
    final bool roomy = height >= 300;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 6, Tokens.gutter, 0),
      child: JellySurface(
        onTap: onTap,
        scale: 0.985,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (image != null)
                  RemoteImage(url: image)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          context.colors.primary.withValues(alpha: 0.86),
                          Tokens.ink,
                        ],
                      ),
                    ),
                  ),
                // Two scrims: a deep one at the bottom for the headline, and a
                // soft one at the top so the glass pill has contrast behind it.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: <double>[0.0, 0.30, 0.62, 1.0],
                      colors: <Color>[
                        Color(0x7A000000),
                        Color(0x14000000),
                        Color(0x8A000000),
                        Color(0xE0000000),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          GlassPanel(
                            tone: GlassTone.subtle,
                            blur: Tokens.blurSoft,
                            radius: Tokens.radiusPill,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Tokens.accentSoft,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (source?.localizedName(bengali: context.isBengali) ??
                                          article.sourceId)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: Tokens.sans,
                                    fontSize: 9.5,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (onOpenSource != null)
                            GlassPanel(
                              tone: GlassTone.subtle,
                              blur: Tokens.blurSoft,
                              radius: Tokens.radiusPill,
                              padding: const EdgeInsets.all(8),
                              child: Pressable(
                                onTap: onOpenSource,
                                scale: 0.9,
                                child: const Icon(
                                  Icons.north_east_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        article.title,
                        maxLines: roomy ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.displaySmall?.copyWith(
                          fontFamily: Tokens.serif,
                          fontSize: 25,
                          height: 1.34,
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const <Shadow>[
                            Shadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                      if (roomy && (article.excerpt ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          article.excerpt!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall?.copyWith(
                            fontSize: 12.5,
                            height: 1.6,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Attribution(
                              article: article,
                              source: source,
                              compact: true,
                              onDark: true,
                            ),
                          ),
                          BookmarkAction(
                            article: article,
                            size: 19,
                            dense: true,
                            onDark: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single headline in the river below the lead.
///
/// Two densities share one structure — text column, optional thumbnail, optional
/// row actions — and the separation is a soft rule, not another card.
class StoryRow extends StatelessWidget {
  const StoryRow({
    super.key,
    required this.article,
    required this.onTap,
    this.source,
    this.last = false,
    this.showThumbnail = true,
    this.trailing,
    this.index = 0,
    this.large = false,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback onTap;
  final bool last;
  final bool showThumbnail;
  final Widget? trailing;
  final int index;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final String? image = article.imageUrl;
    final double thumb = large ? 96 : 78;

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: large ? 16 : 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (large) ...<Widget>[
                    Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Attribution(article: article, source: source, compact: true),
                        const SizedBox(height: 5),
                        Text(
                          article.title,
                          maxLines: large ? 3 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: (large
                                  ? context.texts.headlineSmall
                                  : context.texts.titleMedium)
                              ?.copyWith(
                            fontFamily: Tokens.serif,
                            fontSize: large ? 18 : 15.5,
                            height: 1.42,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.05,
                          ),
                        ),
                        if (!large && (article.excerpt ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            article.excerpt!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.5,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showThumbnail && image != null) ...<Widget>[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      child: SizedBox(
                        width: thumb,
                        height: thumb,
                        child: RemoteImage(url: image),
                      ),
                    ),
                  ],
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 2),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (!last) const SoftRule(inset: 0, opacity: 0.75),
          ],
        ),
      ),
    );
  }
}

/// A wide, editorial list tile used by section lists and search results.
class StoryTile extends StatelessWidget {
  const StoryTile({
    super.key,
    required this.article,
    required this.onTap,
    this.source,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 12),
      child: PaperCard(
        padding: const EdgeInsets.all(14),
        radius: Tokens.radiusMd,
        child: Pressable(
          onTap: onTap,
          scale: 0.99,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Attribution(article: article, source: source, compact: true),
              const SizedBox(height: 6),
              Text(
                article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.texts.headlineSmall?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 16.5,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((article.excerpt ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  article.excerpt!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(height: 1.55),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference's news row: a translucent card, thumbnail on the left, headline
/// on the right, then a meta line with the share and bookmark controls sitting
/// under the text.
///
/// Cards are used only for the river; the lead and the featured rail stay
/// unboxed so the page still has three distinct densities instead of one
/// repeated rectangle.
class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.source,
    this.index = 0,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final String? image = article.imageUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 10),
      child: AnimatedContainer(
        duration: Motion.of(context).standard,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? <Color>[
                    Colors.white.withValues(alpha: 0.075),
                    Colors.white.withValues(alpha: 0.035),
                  ]
                : <Color>[
                    Colors.white.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.72),
                  ],
          ),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.9),
            width: 0.9,
          ),
          boxShadow: Tokens.shadow(context, lift: 0.45),
        ),
        child: JellySurface(
          onTap: onTap,
          scale: 0.988,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (image != null) ...<Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tokens.radiusXs),
                          child: SizedBox(
                            width: 92,
                            height: 88,
                            child: RemoteImage(url: image),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: image != null ? 88 : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                article.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: Tokens.serif,
                                  fontSize: 15.5,
                                  height: 1.45,
                                  letterSpacing: -0.05,
                                  fontWeight: FontWeight.w600,
                                  color: dark ? Tokens.nightInk : Tokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      if (source != null) ...<Widget>[
                        Container(
                          width: 15,
                          height: 15,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.primary.withValues(alpha: 0.22),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            source!.monogram.characters.take(1).toString(),
                            style: TextStyle(
                              fontFamily: Tokens.serif,
                              fontSize: 7.5,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Attribution(
                          article: article,
                          source: source,
                          compact: true,
                        ),
                      ),
                      const Spacer(),
                      ShareAction(article: article, size: 15, dense: true),
                      const SizedBox(width: 2),
                      BookmarkAction(
                        article: article,
                        size: 16,
                        dense: true,
                        showSnack: false,
                      ),
                    ],
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
