import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../helpers/app_nav.dart';
import '../widgets/article_card.dart';
import '../widgets/common.dart';
import '../widgets/feed_filter_sheet.dart';
import '../widgets/feed_widgets.dart';
import 'newspapers_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageStep = 8;
  int _visible = _pageStep;

  Future<void> _refresh() => context.read<FeedController>().refresh(force: true);

  void _toggleTopic(ArticleTopic topic) {
    HapticFeedback.selectionClick();
    final FeedController feed = context.read<FeedController>();
    unawaited(feed.applyQuery(feed.query.toggleTopic(topic)));
  }

  void _clearTopics() {
    final FeedController feed = context.read<FeedController>();
    unawaited(feed.applyQuery(feed.query.copyWith(topics: const <ArticleTopic>{})));
  }

  void _setFollowing(bool following) {
    HapticFeedback.selectionClick();
    unawaited(context.read<FeedController>().setFollowedOnly(following));
  }

  @override
  Widget build(BuildContext context) {
    final FeedController feed = context.watch<FeedController>();
    final SettingsController settings = context.watch<SettingsController>();
    final SourceRegistry registry = context.registry;
    final List<Article> articles = feed.articles;
    final Article? hero = articles.isNotEmpty ? articles.first : null;
    final List<Article> rest = articles.skip(1).take(_visible).toList();
    final List<NewsSource> followed = <NewsSource>[
      for (final String id in settings.followedSourceIds)
        if (registry.byId(id) != null) registry.byId(id)!,
    ];
    final List<NewsSource> featured = registry.featured.take(10).toList();
    final bool bengali = context.isBengali;

    return RefreshIndicator(
      onRefresh: _refresh,
      edgeOffset: 72,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            toolbarHeight: 66,
            titleSpacing: 20,
            title: Row(
              children: <Widget>[
                const _BrandMark(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.strings.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleMedium?.copyWith(
                          fontSize: 14.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Text(
                        context.strings.appTagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: context.strings.filterTitle,
                onPressed: () => showFeedFilterSheet(context),
                icon: Badge(
                  isLabelVisible: feed.query.sourceIds.isNotEmpty ||
                      feed.query.languages.isNotEmpty,
                  child: const Icon(Icons.tune_rounded),
                ),
              ),
              IconButton(
                tooltip: context.strings.searchTitle,
                onPressed: () => Navigator.of(context).push<void>(
                  editorialRoute<void>(const SearchScreen(), name: 'search'),
                ),
                icon: const Icon(Icons.search_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 6),
                TopicRail(
                  selected: feed.query.topics,
                  onToggle: _toggleTopic,
                  onClear: _clearTopics,
                ),
                const SizedBox(height: 10),
                FeedStatusBar(onRefresh: _refresh),
                if (feed.lastError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      feed.lastError!,
                      style: context.texts.labelSmall?.copyWith(color: context.colors.error),
                    ),
                  ),
                BreakingBanner(articles: feed.breakingArticles, onOpen: (Article a) => openArticle(context, a)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final Widget heading = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.strings.latestNews,
                            style: context.texts.headlineSmall?.copyWith(fontSize: 20),
                          ),
                          Text(
                            context.strings.latestNewsSubtitle,
                            style: context.texts.labelSmall,
                          ),
                        ],
                      );
                      // The pill row has an intrinsic width; scale it down
                      // rather than overflow however narrow the header gets.
                      final Widget toggle = FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: _FollowingToggle(
                          following: feed.query.followedOnly,
                          onChanged: _setFollowing,
                        ),
                      );
                      // Below ~300dp the pill row and the Bengali heading cannot
                      // share a line without squeezing the heading into columns.
                      if (constraints.maxWidth < 300) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            heading,
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: toggle,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          Expanded(child: heading),
                          Flexible(child: toggle),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (feed.isLoading && articles.isEmpty)
            const SliverToBoxAdapter(child: ArticleSkeleton(count: 5))
          else if (articles.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: EmptyState(
                  icon: feed.isOffline ? Icons.cloud_off_rounded : Icons.article_outlined,
                  title: context.strings.emptyFeedTitle,
                  body: feed.isOffline
                      ? context.strings.offlineNotice
                      : feed.query.followedOnly
                          ? context.strings.noFollowedBody
                          : context.strings.emptyFeedBody,
                  actionLabel: context.strings.retry,
                  onAction: _refresh,
                ),
              ),
            )
          else ...<Widget>[
            if (hero != null)
              SliverToBoxAdapter(
                child: ArticleCard(
                  article: hero,
                  source: registry.byId(hero.sourceId),
                  variant: ArticleCardVariant.hero,
                  onTap: () => openArticle(context, hero),
                ),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final Article article = rest[index];
                  return Column(
                    children: <Widget>[
                      ArticleCard(
                        article: article,
                        source: registry.byId(article.sourceId),
                        onTap: () => openArticle(context, article),
                      ),
                      if (index != rest.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.6,
                          indent: 20,
                          endIndent: 20,
                          color: context.colors.outlineVariant,
                        ),
                    ],
                  );
                },
                childCount: rest.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                child: Column(
                  children: <Widget>[
                    if (_visible < articles.length || articles.length >= feed.query.limit)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (_visible < articles.length) {
                              setState(() => _visible += _pageStep);
                            } else {
                              await context.read<FeedController>().loadMore();
                              if (mounted) setState(() => _visible += _pageStep);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: context.colors.outlineVariant),
                          ),
                          child: Text(context.strings.viewAll),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.done_all_rounded, size: 14, color: context.texts.labelSmall?.color),
                        const SizedBox(width: 6),
                        Text(context.strings.feedEnd, style: context.texts.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (followed.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: context.strings.followedPapers,
                    actionLabel: context.strings.viewAll,
                    onAction: () => openArticleList(
                      context,
                      title: context.strings.followedPapers,
                      sourceIds: followed.map((NewsSource s) => s.id).toSet(),
                    ),
                  ),
                  FollowStrip(
                    sources: followed,
                    onOpen: (NewsSource s) => openSource(context, s),
                    onBrowse: () => _openDirectory(context),
                  ),
                  const SizedBox(height: 18),
                ],
                if (featured.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: context.strings.featuredPapers,
                    actionLabel: context.strings.browseDirectory,
                    onAction: () => _openDirectory(context),
                  ),
                  _FeaturedRail(
                    sources: featured,
                    onOpen: (NewsSource s) => openSource(context, s),
                  ),
                  const SizedBox(height: 20),
                ],
                PrimaryActionCard(
                  icon: Icons.newspaper_rounded,
                  title: context.strings.directoryTitle,
                  subtitle: bengali
                      ? '${registry.sources.length}টি পত্রিকা, পোর্টাল ও ই-পেপার'
                      : '${registry.sources.length} publications, portals and e-papers',
                  onTap: () => _openDirectory(context),
                ),
                const SizedBox(height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDirectory(BuildContext context) {
    Navigator.of(context).push<void>(
      editorialRoute<void>(
        const NewspapersScreen(standalone: true),
        name: 'directory',
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? <Color>[AppColors.mint, AppColors.brandGreenBright]
              : <Color>[AppColors.brandGreen, AppColors.brandGreenBright],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.newspaper_rounded,
        size: 20,
        color: context.isDark ? AppColors.nightBg : Colors.white,
      ),
    );
  }
}

class _FollowingToggle extends StatelessWidget {
  const _FollowingToggle({required this.following, required this.onChanged});

  final bool following;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context).fast,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: active ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? context.colors.onPrimary : context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          pill(context.strings.all, !following, () => onChanged(false)),
          pill(context.strings.followingLabel, following, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _FeaturedRail extends StatelessWidget {
  const _FeaturedRail({required this.sources, required this.onOpen});

  final List<NewsSource> sources;
  final ValueChanged<NewsSource> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: sources.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final NewsSource source = sources[index];
          return InkWell(
            onTap: () => onOpen(source),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 136,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SourceAvatar(source: source, size: 36),
                  const Spacer(),
                  Text(
                    source.localizedName(bengali: context.isBengali),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(fontSize: 12.5, height: 1.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    publicationMeta(source, bengali: context.isBengali),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
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
