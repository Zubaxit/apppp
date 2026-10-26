import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial.dart';
import '../widgets/feed_widgets.dart';
import 'epaper_directory_screen.dart';
import 'newspapers_screen.dart';

/// Categories: a directed grid of sections rather than a wall of identical
/// boxes. Each tile is a glass surface with its own icon, an accent hairline and
/// the live count of stories currently cached for that section.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  /// The registry of sections the app offers. Education stays one section —
  /// admissions, exams, results and universities all live there — and the four
  /// career and knowledge sections are additions, not replacements.
  static const List<ArticleTopic> _topics = <ArticleTopic>[
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
    final FeedController feed = context.watch<FeedController>();
    final Map<ArticleTopic, int> counts = <ArticleTopic, int>{};
    for (final Article article in feed.articles) {
      counts[article.topic] = (counts[article.topic] ?? 0) + 1;
    }
    final SourceRegistry registry = context.registry;
    final List<String> divisions = registry.divisionsWithSources;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              toolbarHeight: 62,
              backgroundColor: context.theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                context.strings.navCategories,
                style: context.texts.titleLarge?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: <Widget>[
                GlassIconButton(
                  icon: Icons.monitor_heart_outlined,
                  tooltip: context.strings.sourceHealth,
                  onTap: () => openSourceHealth(context),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter, 4, Tokens.gutter, 16),
                    child: Text(
                      context.strings.categoriesSubtitle,
                      style: context.texts.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Tokens.gutter),
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.42,
                      ),
                      itemCount: _topics.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ArticleTopic topic = _topics[index];
                        return RiseIn(
                          index: index,
                          offset: 12,
                          child: _TopicTile(
                            topic: topic,
                            index: index,
                            count: counts[topic] ?? 0,
                            onTap: () => openArticleList(
                              context,
                              title: Labels.topic(topic, bengali: bengali),
                              subtitle: bengali
                                  ? 'এই বিভাগের সর্বশেষ খবর'
                                  : 'Latest in this section',
                              topics: <ArticleTopic>{topic},
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: context.strings.regionalSources,
                    subtitle: bengali
                        ? 'বিভাগ অনুযায়ী আঞ্চলিক পত্রিকা'
                        : 'Regional publications by division',
                  ),
                  if (divisions.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Tokens.gutter),
                      child: Text(
                        context.strings.regionalEmpty,
                        style: context.texts.bodySmall,
                      ),
                    )
                  else
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: Tokens.gutter),
                        physics: const BouncingScrollPhysics(),
                        children: <Widget>[
                          for (final String division in divisions) ...<Widget>[
                            GlassChip(
                              label:
                                  '$division · ${registry.sources.where((NewsSource s) => s.division == division).length}',
                              icon: Icons.map_outlined,
                              onTap: () => _openRegional(context, division),
                              dense: true,
                            ),
                            const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 26),
                  SectionHeader(title: context.strings.browseDirectory),
                  PrimaryActionCard(
                    icon: Icons.newspaper_rounded,
                    title: context.strings.directoryTitle,
                    body: bengali
                        ? '${BengaliText.toBengaliDigits(registry.sources.length)}টি উৎস · '
                            '${BengaliText.toBengaliDigits(registry.epapers.length)}টি ই-পেপার'
                        : '${registry.sources.length} sources · '
                            '${registry.epapers.length} e-papers',
                    onTap: () => Navigator.of(context).push<void>(
                      editorialRoute<void>(
                        const NewspapersScreen(standalone: true),
                        name: 'directory',
                      ),
                    ),
                  ),
                  PrimaryActionCard(
                    icon: Icons.menu_book_rounded,
                    title: context.strings.epaperSectionTitle,
                    body: bengali
                        ? 'পত্রিকার ই-পেপার সংস্করণ'
                        : 'Publisher e-paper editions',
                    onTap: () => Navigator.of(context).push<void>(
                      editorialRoute<void>(const EpaperDirectoryScreen(),
                          name: 'epapers'),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRegional(BuildContext context, String division) {
    Navigator.of(context).push<void>(
      editorialRoute<void>(
        NewspapersScreen(standalone: true, initialDivision: division),
        name: 'regional',
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final ArticleTopic topic;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final bool dark = context.isDark;
    return JellySurface(
      onTap: onTap,
      scale: 0.955,
      child: GlassPanel(
        radius: Tokens.radiusMd,
        // Sits in the scrolling column over the static backdrop, so the fill
        // and hairline carry the material and no blur pass runs per frame.
        blur: 0,
        elevation: 0.6,
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: <Widget>[
            // A large, very low-contrast index numeral: a printed folio mark
            // rather than decoration for its own sake.
            Positioned(
              right: -4,
              top: -10,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: Tokens.serif,
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: (dark ? Colors.white : Tokens.ink)
                      .withValues(alpha: 0.045),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.primary
                        .withValues(alpha: dark ? 0.18 : 0.09),
                    borderRadius: BorderRadius.circular(Tokens.radiusXs),
                  ),
                  child: Icon(
                    Labels.topicIcon(topic),
                    size: 17,
                    color: context.colors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  Labels.topic(topic, bengali: bengali),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    fontFamily: Tokens.serif,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 1.6,
                      color: context.colors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      count == 0
                          ? (bengali ? 'শীঘ্রই' : 'Soon')
                          : (bengali
                              ? '${BengaliText.toBengaliDigits(count)} টি খবর'
                              : '$count stories'),
                      style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
