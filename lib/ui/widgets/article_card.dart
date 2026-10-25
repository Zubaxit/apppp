import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/saved_controller.dart';
import '../../theme/materials.dart';
import '../../theme/tokens.dart';
import 'actions.dart';
import 'common.dart';
import 'editorial.dart';

enum ArticleCardVariant { hero, standard, compact, saved }

/// Editorial article card. Four densities share one visual language: a paper
/// surface, a serif headline, a hairline attribution line and a glass bookmark.
///
/// It is deliberately a flat sheet rather than glass: text gets the full
/// contrast of paper, and glass is reserved for the chrome that floats over it.
class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    required this.source,
    this.variant = ArticleCardVariant.standard,
    this.onTap,
    this.showExcerpt = true,
    this.index = 0,
  });

  final Article article;
  final NewsSource? source;
  final ArticleCardVariant variant;
  final VoidCallback? onTap;
  final bool showExcerpt;
  final int index;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case ArticleCardVariant.hero:
        return _Hero(article: article, source: source, onTap: onTap);
      case ArticleCardVariant.compact:
        return _Compact(article: article, source: source, onTap: onTap);
      case ArticleCardVariant.saved:
        return _Saved(article: article, source: source, onTap: onTap);
      case ArticleCardVariant.standard:
        return _Standard(
          article: article,
          source: source,
          onTap: onTap,
          showExcerpt: showExcerpt,
        );
    }
  }
}

class _Standard extends StatelessWidget {
  const _Standard({
    required this.article,
    required this.source,
    required this.onTap,
    required this.showExcerpt,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback? onTap;
  final bool showExcerpt;

  @override
  Widget build(BuildContext context) {
    final String? image = article.imageUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 12),
      child: PaperCard(
        padding: const EdgeInsets.all(13),
        radius: Tokens.radiusMd,
        child: Pressable(
          onTap: onTap,
          scale: 0.99,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (image != null) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: RemoteImage(url: image, decodeWidth: 380),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              if (showExcerpt && (article.excerpt ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  article.excerpt!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(height: 1.55),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (article.topic != ArticleTopic.other)
                    Text(
                      topicLabel(article.topic, bengali: context.isBengali),
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 9.5,
                        letterSpacing: 0.6,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  BookmarkAction(article: article, dense: true, showSnack: false),
                  ShareAction(article: article, size: 17, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.article, required this.source, required this.onTap});

  final Article article;
  final NewsSource? source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 14),
      child: PaperCard(
        padding: const EdgeInsets.all(14),
        radius: Tokens.radiusLg,
        child: Pressable(
          onTap: onTap,
          scale: 0.985,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Attribution(article: article, source: source, compact: true),
              const SizedBox(height: 8),
              Text(
                article.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppThemeText.hero(context),
              ),
              if ((article.excerpt ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 9),
                Text(
                  article.excerpt!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyMedium?.copyWith(height: 1.65),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  BookmarkAction(article: article, dense: true),
                  const SizedBox(width: 6),
                  ShareAction(article: article, size: 18, dense: true),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Compact extends StatelessWidget {
  const _Compact({required this.article, required this.source, required this.onTap});

  final Article article;
  final NewsSource? source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String? image = article.imageUrl;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, 12),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Attribution(article: article, source: source, compact: true),
                      const SizedBox(height: 5),
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleMedium?.copyWith(
                          fontFamily: Tokens.serif,
                          fontSize: 15.5,
                          height: 1.42,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (image != null) ...<Widget>[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    child: SizedBox(
                      width: 74,
                      height: 74,
                      child: RemoteImage(
                        url: image,
                        decodeWidth: 74,
                        fade: false,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const SoftRule(opacity: 0.6),
          ],
        ),
      ),
    );
  }
}

/// Saved rows show how the item was kept, which is different from a plain list.
class _Saved extends StatelessWidget {
  const _Saved({required this.article, required this.source, required this.onTap});

  final Article article;
  final NewsSource? source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool saved = context.select<SavedController, bool>(
      (SavedController controller) => controller.isSaved(article.id),
    );
    final bool hasExcerpt = (article.excerpt ?? '').trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 12),
      child: PaperCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        radius: Tokens.radiusMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
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
                        fontSize: 15.5,
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          hasExcerpt ? Icons.notes_rounded : Icons.link_rounded,
                          size: 11,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasExcerpt
                              ? context.strings.savedExcerptBadge
                              : context.strings.savedLinkOnlyBadge,
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 9.5,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: <Widget>[
                BookmarkAction(article: article, dense: true, showSnack: false),
                if (saved) const SizedBox(height: 4),
                ShareAction(article: article, size: 16, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact publisher + time line, used where [Attribution] is too wide.
class ArticleMetaRow extends StatelessWidget {
  const ArticleMetaRow({
    super.key,
    required this.article,
    required this.source,
    this.emphasis = false,
    this.dense = false,
  });

  final Article article;
  final NewsSource? source;
  final bool emphasis;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String name = source?.localizedName(bengali: bengali) ?? article.sourceId;
    final String? time = BengaliText.relative(article.publishedAt, bengali: bengali);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (source != null) ...<Widget>[
          SourceAvatar(source: source!, size: dense ? 18 : 22),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              fontSize: dense ? 10 : 10.6,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: 0.4,
              color: context.colors.primary,
            ),
          ),
        ),
        if (time != null) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            '· $time',
            style: context.texts.labelSmall?.copyWith(fontSize: dense ? 9.5 : 10.5),
          ),
        ],
      ],
    );
  }
}

/// Human labels for topics, in the active language.
String topicLabel(ArticleTopic topic, {required bool bengali}) =>
    Labels.topicShort(topic, bengali: bengali);

/// Headline styles shared by the hero card and the reader.
class AppThemeText {
  const AppThemeText._();

  static TextStyle hero(BuildContext context) => TextStyle(
        fontFamily: Tokens.serif,
        fontSize: 25,
        height: 1.32,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
