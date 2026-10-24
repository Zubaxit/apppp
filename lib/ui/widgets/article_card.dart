import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/saved_controller.dart';
import '../../theme/app_theme.dart';
import 'common.dart';

enum ArticleCardVariant { hero, standard, compact, saved }

/// Editorial article card. Three densities share one visual language so the
/// home feed, section lists and search results all feel like one publication.
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
    final bool saved = context.watch<SavedController>().isSaved(article.id);
    final Widget content = _contentFor(context, saved);
    return Semantics(
      button: true,
      label: article.title,
      // The card is rendered in lists, sheets and dialogs; provide the Material
      // the ink response needs instead of assuming an ancestor supplies it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
  }

  Widget _contentFor(BuildContext context, bool saved) {
    switch (variant) {
      case ArticleCardVariant.hero:
        return _buildHero(context, saved);
      case ArticleCardVariant.compact:
        return _buildCompact(context, saved);
      case ArticleCardVariant.saved:
        return _buildStandard(context, saved, savedDate: true);
      case ArticleCardVariant.standard:
        return _buildStandard(context, saved);
    }
  }

  Widget _buildHero(BuildContext context, bool saved) {
    final double scale = context.settings.textScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (article.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: RemoteImage(url: article.imageUrl!),
              ),
            ),
          const SizedBox(height: 14),
          ArticleMetaRow(article: article, source: source, emphasis: true),
          const SizedBox(height: 8),
          Text(
            article.title,
            style: AppTheme.headlineStyle(context.theme, scale: scale, hero: true),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (showExcerpt && (article.excerpt ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              article.excerpt!,
              style: context.texts.bodyMedium?.copyWith(
                fontSize: 14.5 * scale,
                color: context.texts.bodySmall?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          _ActionRow(article: article, saved: saved),
        ],
      ),
    );
  }

  Widget _buildStandard(BuildContext context, bool saved, {bool savedDate = false}) {
    final double scale = context.settings.textScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ArticleMetaRow(article: article, source: source),
                    const SizedBox(height: 7),
                    Text(
                      article.title,
                      style: AppTheme.headlineStyle(context.theme, scale: scale, hero: false)
                          .copyWith(fontSize: 18 * scale),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showExcerpt && (article.excerpt ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        article.excerpt!,
                        style: context.texts.bodySmall?.copyWith(fontSize: 13 * scale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (article.imageUrl != null) ...<Widget>[
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: RemoteImage(url: article.imageUrl!),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _BookmarkButton(article: article, saved: saved),
              const Spacer(),
              if (savedDate)
                Text(
                  BengaliText.absolute(article.fetchedAt, bengali: context.isBengali),
                  style: context.texts.labelSmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, bool saved) {
    final double scale = context.settings.textScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  article.title,
                  style: context.texts.titleMedium?.copyWith(
                    fontSize: 14.5 * scale,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ArticleMetaRow(article: article, source: source, dense: true),
              ],
            ),
          ),
          _BookmarkButton(article: article, saved: saved, dense: true),
        ],
      ),
    );
  }
}

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
    final Color primary = context.colors.primary;
    final Color? muted = context.texts.labelSmall?.color;
    return Row(
      children: <Widget>[
        if (article.breaking) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.colors.error,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              context.strings.breakingShort,
              style: TextStyle(
                color: context.colors.onError,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (emphasis ? context.texts.labelLarge : context.texts.labelMedium)
                ?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : null,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            time ?? context.strings.noPublicationDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              color: time == null ? muted?.withValues(alpha: 0.85) : muted,
              fontSize: dense ? 10.5 : null,
              fontStyle: time == null ? FontStyle.italic : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.article, required this.saved});

  final Article article;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _BookmarkButton(article: article, saved: saved),
        const SizedBox(width: 4),
        if (article.topic != ArticleTopic.other)
          Text(
            bengaliTopicLabel(context, article.topic),
            style: context.texts.labelSmall?.copyWith(color: context.colors.primary),
          ),
        const Spacer(),
        Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: context.colors.primary.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

String bengaliTopicLabel(BuildContext context, ArticleTopic topic) {
  // Avoid a circular import with the labels helper for this small case.
  final bool bengali = context.isBengali;
  if (bengali) {
    return const <ArticleTopic, String>{
      ArticleTopic.bangladesh: 'বাংলাদেশ',
      ArticleTopic.politics: 'রাজনীতি',
      ArticleTopic.economy: 'অর্থনীতি',
      ArticleTopic.international: 'আন্তর্জাতিক',
      ArticleTopic.education: 'শিক্ষা',
      ArticleTopic.sports: 'খেলা',
      ArticleTopic.entertainment: 'বিনোদন',
      ArticleTopic.technology: 'প্রযুক্তি',
      ArticleTopic.health: 'স্বাস্থ্য',
      ArticleTopic.lifestyle: 'জীবনযাপন',
      ArticleTopic.other: 'অন্যান্য',
    }[topic]!;
  }
  return topic.name;
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({
    required this.article,
    required this.saved,
    this.dense = false,
  });

  final Article article;
  final bool saved;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    return IconButton(
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      iconSize: dense ? 18 : 20,
      padding: EdgeInsets.all(dense ? 4 : 8),
      constraints: const BoxConstraints(),
      tooltip: saved ? context.strings.removeSaved : context.strings.save,
      // The mark fills, settles with a short overshoot and the tap gives a
      // haptic tick — small, but it is the gesture readers repeat most.
      icon: AnimatedSwitcher(
        duration: motion.fast,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          if (motion.reduce) return child;
          return ScaleTransition(
            scale: Tween<double>(begin: 0.72, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          key: ValueKey<bool>(saved),
          color: saved ? context.colors.primary : context.texts.labelSmall?.color,
        ),
      ),
      onPressed: () async {
        HapticFeedback.lightImpact();
        final bool nowSaved = await context.read<SavedController>().toggle(article);
        if (!context.mounted) return;
        context.showSnack(nowSaved ? context.strings.savedLabel : context.strings.removeSaved);
      },
    );
  }
}
