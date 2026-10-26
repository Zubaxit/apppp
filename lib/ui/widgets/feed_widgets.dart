import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'common.dart';
import 'editorial.dart';

/// Icon per topic, used by the rail and the category screen so the two agree.
IconData topicIcon(ArticleTopic topic) {
  return <ArticleTopic, IconData>{
    ArticleTopic.bangladesh: Icons.public_rounded,
    ArticleTopic.editorial: Icons.edit_note_rounded,
    ArticleTopic.politics: Icons.account_balance_rounded,
    ArticleTopic.economy: Icons.trending_up_rounded,
    ArticleTopic.international: Icons.language_rounded,
    ArticleTopic.education: Icons.school_rounded,
    ArticleTopic.sports: Icons.sports_cricket_rounded,
    ArticleTopic.entertainment: Icons.theaters_rounded,
    ArticleTopic.technology: Icons.memory_rounded,
    ArticleTopic.health: Icons.favorite_border_rounded,
    ArticleTopic.lifestyle: Icons.local_cafe_rounded,
    ArticleTopic.jobs: Icons.work_outline_rounded,
    ArticleTopic.learning: Icons.lightbulb_outline_rounded,
    ArticleTopic.government: Icons.campaign_outlined,
    ArticleTopic.scholarships: Icons.workspace_premium_outlined,
    ArticleTopic.other: Icons.more_horiz_rounded,
  }[topic]!;
}

/// The topic rail: frosted chips that scroll horizontally, with a leading
/// "all" chip. Selection is a tinted glass capsule, not a filled block.
class TopicRail extends StatelessWidget {
  const TopicRail({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final Set<ArticleTopic> selected;
  final ValueChanged<ArticleTopic> onToggle;
  final VoidCallback onClear;

  /// The full topic set, in the order the rail shows it. The four career and
  /// knowledge sections sit after the ten it shipped with, so the rail keeps its
  /// familiar first screen.
  static const List<ArticleTopic> topics = <ArticleTopic>[
    ArticleTopic.bangladesh,
    ArticleTopic.editorial,
    ArticleTopic.politics,
    ArticleTopic.economy,
    ArticleTopic.international,
    ArticleTopic.sports,
    ArticleTopic.entertainment,
    ArticleTopic.technology,
    ArticleTopic.education,
    ArticleTopic.health,
    ArticleTopic.lifestyle,
    ArticleTopic.jobs,
    ArticleTopic.learning,
    ArticleTopic.government,
    ArticleTopic.scholarships,
  ];

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          GlassChip(
            label: context.strings.all,
            selected: selected.isEmpty,
            onTap: onClear,
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(width: 7),
          for (final ArticleTopic topic in topics) ...<Widget>[
            GlassChip(
              label: Labels.topicShort(topic, bengali: bengali),
              selected: selected.contains(topic),
              onTap: () => onToggle(topic),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

/// Breaking news, shown only when a publisher labelled an item itself.
///
/// The band is a tinted glass strip with a red signal dot, and it slides in
/// rather than popping.
class BreakingBanner extends StatelessWidget {
  const BreakingBanner(
      {super.key, required this.articles, required this.onOpen});

  final List<Article> articles;
  final ValueChanged<Article> onOpen;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final Article first = articles.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, 0),
      child: JellySurface(
        onTap: () => onOpen(first),
        scale: 0.985,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            color: context.colors.error.withValues(alpha: 0.08),
            border: Border.all(
              color: context.colors.error.withValues(alpha: 0.26),
              width: 0.9,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.error,
                  borderRadius: BorderRadius.circular(Tokens.radiusXs),
                ),
                child: Text(
                  context.strings.breakingNews,
                  style: TextStyle(
                    fontFamily: Tokens.sans,
                    fontSize: 9,
                    height: 1.2,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  first.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    fontFamily: Tokens.serif,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Freshness line with a refresh affordance; states cached/offline honestly.
class FeedStatusBar extends StatelessWidget {
  const FeedStatusBar({super.key, this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// A publisher row: monogram, names, health and a follow control.
class PublicationTile extends StatelessWidget {
  const PublicationTile({
    super.key,
    required this.source,
    this.onTap,
    this.health,
    this.following = false,
    this.onFollow,
    this.showHealth = true,
  });

  final NewsSource source;
  final VoidCallback? onTap;
  final SourceHealth? health;
  final bool following;
  final VoidCallback? onFollow;
  final bool showHealth;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String name = source.localizedName(bengali: bengali);
    final String? other = source.secondaryName(bengali: bengali);
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(Tokens.gutter, 10, Tokens.gutter, 10),
        child: Row(
          children: <Widget>[
            SourceAvatar(source: source, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(
                      fontFamily: Tokens.serif,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (other != null)
                    Text(
                      other,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(fontSize: 10),
                    ),
                  if (showHealth) ...<Widget>[
                    const SizedBox(height: 5),
                    HealthBadge(health: health, hasFeed: source.hasFeed),
                  ],
                ],
              ),
            ),
            if (onFollow != null)
              Semantics(
                button: true,
                label: following
                    ? context.strings.followingLabel
                    : context.strings.follow,
                child: JellySurface(
                  onTap: onFollow,
                  scale: 0.88,
                  child: AnimatedContainer(
                    duration: Motion.of(context).standard,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: following
                          ? context.colors.primary.withValues(alpha: 0.14)
                          : (context.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.7)),
                      border: Border.all(
                        color: following
                            ? context.colors.primary.withValues(alpha: 0.4)
                            : (context.isDark
                                ? Tokens.nightHairline
                                : Tokens.hairline),
                        width: 0.9,
                      ),
                    ),
                    child: Icon(
                      following
                          ? Icons.check_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 17,
                      color: following
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The followed-publications rail shown under the front page header.
class FollowStrip extends StatelessWidget {
  const FollowStrip({
    super.key,
    required this.sources,
    required this.onOpen,
    required this.onBrowse,
  });

  final List<NewsSource> sources;
  final ValueChanged<NewsSource> onOpen;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          for (final NewsSource source in sources) ...<Widget>[
            JellySurface(
              onTap: () => onOpen(source),
              scale: 0.93,
              child: SizedBox(
                width: 64,
                child: Column(
                  children: <Widget>[
                    SourceAvatar(source: source, size: 50),
                    const SizedBox(height: 6),
                    Text(
                      source.localizedName(bengali: context.isBengali),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          JellySurface(
            onTap: onBrowse,
            scale: 0.93,
            child: SizedBox(
              width: 64,
              child: Column(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colors.outlineVariant,
                        width: 0.9,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.strings.browseDirectory,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: context.texts.labelSmall?.copyWith(fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic row of filter chips backed by any comparable value.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelect,
    this.allLabel,
    this.allValue,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T? selected;
  final ValueChanged<T?> onSelect;
  final String? allLabel;
  final T? allValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          if (allLabel != null) ...<Widget>[
            GlassChip(
              label: allLabel!,
              selected: selected == allValue,
              onTap: () => onSelect(allValue),
              dense: true,
            ),
            const SizedBox(width: 7),
          ],
          for (final T value in values) ...<Widget>[
            GlassChip(
              label: labelOf(value),
              selected: selected == value,
              onTap: () => onSelect(value),
              dense: true,
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

/// Vertical spacer with a fading rule, used between editorial groups.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.height = 26});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 2),
      child: const SoftRule(inset: Tokens.gutter, opacity: 0.7),
    );
  }
}

/// Large tappable panel with an icon, a title and a body — used by Categories
/// and Search as the entry point into the directory.
class PrimaryActionCard extends StatelessWidget {
  const PrimaryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.accent,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Color? accent;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? context.colors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 12),
      child: PaperCard(
        padding: const EdgeInsets.all(15),
        radius: Tokens.radiusMd,
        child: Pressable(
          onTap: onTap,
          scale: 0.985,
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  border: Border.all(
                      color: tint.withValues(alpha: 0.2), width: 0.9),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.texts.titleSmall?.copyWith(
                        fontFamily: Tokens.serif,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                    if (trailingLabel != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        trailingLabel!,
                        style: context.texts.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A number with a caption, used in About and the directory header.
class StatBlock extends StatelessWidget {
  const StatBlock(
      {super.key, required this.value, required this.label, this.accent});

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
            fontFamily: Tokens.serif,
            fontSize: 22,
            color: accent ?? context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(fontSize: 9.5, height: 1.3),
          maxLines: 2,
        ),
      ],
    );
  }
}

/// A category entry shaped like the reference: a circular glass tile with the
/// glyph, and its label underneath. Selection tints the tile and the glyph red
/// and thickens the label — the circle responds on touch-down through the jelly
/// spring, which is what makes the row feel like a physical control strip.
class CategoryCircle extends StatelessWidget {
  const CategoryCircle({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color accent = context.colors.primary;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: JellySurface(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: Motion.of(context).standard,
                curve: Tokens.easeStandard,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? <Color>[
                            accent.withValues(alpha: dark ? 0.34 : 0.20),
                            accent.withValues(alpha: dark ? 0.20 : 0.10),
                          ]
                        : (dark
                            ? <Color>[
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.045),
                              ]
                            : <Color>[
                                Colors.white.withValues(alpha: 0.92),
                                Colors.white.withValues(alpha: 0.66),
                              ]),
                  ),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.55)
                        : (dark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Tokens.hairline),
                    width: 0.9,
                  ),
                  // No blurred shadow: thirteen of these sit in one strip and
                  // each shadow is a blurred raster of its own.
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color:
                      selected ? accent : (dark ? Tokens.nightInk : Tokens.ink),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Tokens.sans,
                  fontSize: 9.5,
                  height: 1.25,
                  letterSpacing: 0.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? accent
                      : (dark ? Tokens.nightInkMuted : Tokens.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The horizontal strip of [CategoryCircle]s, with an "all" entry first.
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final Set<ArticleTopic> selected;
  final ValueChanged<ArticleTopic> onToggle;
  final VoidCallback onClear;

  /// Same set as [TopicRail.topics], ordered by what readers open first.
  static const List<ArticleTopic> topics = <ArticleTopic>[
    ArticleTopic.bangladesh,
    ArticleTopic.international,
    ArticleTopic.sports,
    ArticleTopic.politics,
    ArticleTopic.entertainment,
    ArticleTopic.technology,
    ArticleTopic.economy,
    ArticleTopic.education,
    ArticleTopic.health,
    ArticleTopic.lifestyle,
    ArticleTopic.jobs,
    ArticleTopic.learning,
    ArticleTopic.scholarships,
    ArticleTopic.government,
  ];

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        physics: const BouncingScrollPhysics(),
        itemCount: topics.length + 1,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return CategoryCircle(
              label: context.strings.all,
              icon: Icons.apps_rounded,
              selected: selected.isEmpty,
              onTap: onClear,
            );
          }
          final ArticleTopic topic = topics[index - 1];
          return CategoryCircle(
            label: Labels.topicShort(topic, bengali: bengali),
            icon: topicIcon(topic),
            selected: selected.contains(topic),
            onTap: () => onToggle(topic),
          );
        },
      ),
    );
  }
}
