import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/tokens.dart';
import 'common.dart';
import 'editorial.dart';

/// The front-page lead: image, kicker, large serif headline, standfirst.
///
/// Deliberately unboxed — no card, no shadow — so the photograph and the type
/// carry the page instead of yet another rounded container.
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
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 14, Tokens.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (image != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: RemoteImage(url: image),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (article.breaking) ...<Widget>[
              const BreakingTag(),
              const SizedBox(height: 8),
            ],
            Pressable(
              onTap: onOpenSource,
              child: Attribution(
                article: article,
                source: source,
                showDot: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: context.texts.displaySmall?.copyWith(
                fontSize: 29,
                height: 1.24,
                letterSpacing: -0.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((article.excerpt ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                article.excerpt!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium?.copyWith(
                  fontSize: 14.5,
                  height: 1.65,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Hairline(strong: true),
          ],
        ),
      ),
    );
  }
}

/// A single headline in the river below the lead.
///
/// Rules do the separating so the list stays calm as it grows.
class StoryRow extends StatelessWidget {
  const StoryRow({
    super.key,
    required this.article,
    required this.onTap,
    this.source,
    this.last = false,
    this.showThumbnail = true,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback onTap;
  final bool last;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    final String? image = article.imageUrl;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (article.breaking) ...<Widget>[
                          const BreakingTag(),
                          const SizedBox(height: 5),
                        ],
                        Attribution(article: article, source: source, compact: true),
                        const SizedBox(height: 5),
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.headlineSmall?.copyWith(
                            fontSize: 17.5,
                            height: 1.36,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((article.excerpt ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: 5),
                          Text(
                            article.excerpt!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.bodySmall?.copyWith(
                              fontSize: 12.5,
                              height: 1.5,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showThumbnail && image != null) ...<Widget>[
                    const SizedBox(width: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        width: 78,
                        height: 78,
                        child: RemoteImage(url: image),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!last) const Hairline(),
          ],
        ),
      ),
    );
  }
}
