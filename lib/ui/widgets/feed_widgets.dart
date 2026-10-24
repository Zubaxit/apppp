import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../state/feed_controller.dart';
import 'common.dart';

/// Horizontal topic rail used on Home and on the Categories screen.
class TopicRail extends StatelessWidget {
  const TopicRail({
    super.key,
    required this.selected,
    required this.onToggle,
    this.onClear,
    this.topics = _defaultTopics,
  });

  static const List<ArticleTopic> _defaultTopics = <ArticleTopic>[
    ArticleTopic.bangladesh,
    ArticleTopic.politics,
    ArticleTopic.economy,
    ArticleTopic.international,
    ArticleTopic.sports,
    ArticleTopic.entertainment,
    ArticleTopic.technology,
    ArticleTopic.education,
    ArticleTopic.health,
    ArticleTopic.lifestyle,
  ];

  final Set<ArticleTopic> selected;
  final ValueChanged<ArticleTopic> onToggle;
  final VoidCallback? onClear;
  final List<ArticleTopic> topics;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: topics.length + 1,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            final bool active = selected.isEmpty;
            return _Pill(
              label: context.strings.all,
              icon: Icons.dynamic_feed_rounded,
              active: active,
              onTap: onClear,
            );
          }
          final ArticleTopic topic = topics[index - 1];
          return _Pill(
            label: Labels.topic(topic, bengali: bengali),
            icon: Labels.topicIcon(topic),
            active: selected.contains(topic),
            onTap: () => onToggle(topic),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = active ? context.colors.primary : context.colors.surfaceContainerHighest;
    final Color fg = active ? context.colors.onPrimary : context.colors.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: fg.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.texts.labelLarge?.copyWith(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Breaking stories only when a publisher explicitly labelled them as such.
class BreakingBanner extends StatelessWidget {
  const BreakingBanner({super.key, required this.articles, required this.onOpen});

  final List<Article> articles;
  final ValueChanged<Article> onOpen;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final bool bengali = context.isBengali;
    final Color red = context.colors.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: red.withValues(alpha: context.isDark ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                context.strings.breakingNews.toUpperCase(),
                style: context.texts.labelSmall?.copyWith(
                  color: red,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...articles.take(3).map((Article article) {
            final String time = BengaliText.relative(article.publishedAt, bengali: bengali) ??
                context.strings.noPublicationDate;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onOpen(article),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      article.title,
                      style: context.texts.titleSmall?.copyWith(
                        fontSize: 14 * context.settings.textScale,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${context.registry.nameOf(article.sourceId, bengali: bengali)} · $time',
                      style: context.texts.labelSmall?.copyWith(color: red.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Shows refresh state, cache age and offline status in one compact bar.
class FeedStatusBar extends StatelessWidget {
  const FeedStatusBar({super.key, this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final FeedController feed = context.watch<FeedController>();
    final bool bengali = context.isBengali;
    final String? updated = BengaliText.relative(feed.lastRefreshAt, bengali: bengali);
    final String label = feed.isRefreshing
        ? '${context.strings.checking} ${feed.progressTotal > 0 ? '${feed.progressDone}/${feed.progressTotal}' : ''}'
        : updated == null
            ? context.strings.neverUpdated
            : '${context.strings.lastUpdated}: $updated';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                feed.isOffline
                    ? Icons.cloud_off_rounded
                    : feed.isShowingCached
                        ? Icons.history_rounded
                        : Icons.cloud_done_rounded,
                size: 15,
                color: feed.isOffline ? context.colors.error : context.colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.trim(),
                  style: context.texts.labelSmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: feed.isRefreshing ? null : onRefresh,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: context.strings.refresh,
                icon: feed.isRefreshing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: feed.progressTotal > 0 ? feed.progress : null,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (feed.isOffline || feed.isShowingCached)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      feed.isOffline ? context.strings.offlineNotice : context.strings.cachedNotice,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 10.5,
                        color: feed.isOffline ? context.colors.error : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Directory row for a single publication.
class PublicationTile extends StatelessWidget {
  const PublicationTile({
    super.key,
    required this.source,
    required this.health,
    required this.following,
    required this.onTap,
    required this.onToggleFollow,
  });

  final NewsSource source;
  final SourceHealth? health;
  final bool following;
  final VoidCallback onTap;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String? secondary = source.secondaryName(bengali: bengali);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(
          children: <Widget>[
            SourceAvatar(source: source, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    source.localizedName(bengali: bengali),
                    style: context.texts.titleMedium?.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondary != null)
                    Text(
                      secondary,
                      style: context.texts.labelSmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      HealthBadge(health: health, hasFeed: source.hasFeed),
                      const SizedBox(width: 8),
                      if (source.isRegional && source.division != null)
                        Flexible(
                          child: Text(
                            source.division!,
                            style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleFollow,
              tooltip: following ? context.strings.followingLabel : context.strings.follow,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                following ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 20,
                color: following ? context.colors.primary : context.colors.onSurfaceVariant,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal follow strip used on the home screen.
class FollowStrip extends StatelessWidget {
  const FollowStrip({super.key, required this.sources, required this.onOpen, required this.onBrowse});

  final List<NewsSource> sources;
  final ValueChanged<NewsSource> onOpen;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: InkWell(
          onTap: onBrowse,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.bookmarks_outlined, size: 18, color: context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.strings.noFollowedPapers,
                    style: context.texts.bodySmall,
                  ),
                ),
                Text(context.strings.browseDirectory, style: context.texts.labelMedium),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: sources.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final NewsSource source = sources[index];
          return InkWell(
            onTap: () => onOpen(source),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 96,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SourceAvatar(source: source, size: 34),
                  const SizedBox(height: 8),
                  Text(
                    source.localizedName(bengali: context.isBengali),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: context.colors.onSurface,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Simple generic filter chip row used by the directory and search screens.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.leadingLabel,
  });

  final List<T?> options;
  final T? selected;
  final String Function(T? value) labelOf;
  final ValueChanged<T?> onSelected;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final T? option = options[index];
          final bool active = option == selected;
          return ChoiceChip(
            label: Text(labelOf(option)),
            selected: active,
            onSelected: (_) => onSelected(option),
            labelStyle: context.texts.labelMedium?.copyWith(
              fontSize: 11.5,
              color: active ? context.colors.onPrimary : context.colors.onSurface,
            ),
            backgroundColor: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
            selectedColor: context.colors.primary,
            side: BorderSide(color: active ? Colors.transparent : context.colors.outlineVariant),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          );
        },
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.height = 26});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class PrimaryActionCard extends StatelessWidget {
  const PrimaryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: context.colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: context.texts.titleSmall),
                      const SizedBox(height: 2),
                      Text(subtitle, style: context.texts.labelSmall),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small reusable stat block for the About screen.
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.value, required this.label, this.accent});

  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: context.texts.headlineMedium?.copyWith(
            color: accent ?? context.colors.primary,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: context.texts.labelSmall),
      ],
    );
  }
}
