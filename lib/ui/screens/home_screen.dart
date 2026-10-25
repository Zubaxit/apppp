import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
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
import '../widgets/editorial_story.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/feed_filter_sheet.dart';
import '../widgets/feed_widgets.dart';
import 'search_screen.dart';

/// The front page.
///
/// Four beats, top to bottom: a frosted masthead, one large editorial moment
/// (the featured rail or the lead story), a floating control card for All /
/// Following and the topic rail, then the river of headlines. The page sits on
/// the aurora backdrop so the glass at the top and the floating controls have
/// something real to refract as the content scrolls under them.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refresh() => context.read<FeedController>().refresh(force: true);

  void _setFollowing(bool following) {
    unawaited(context.read<FeedController>().setFollowedOnly(following));
  }

  void _toggleTopic(ArticleTopic topic) {
    final FeedController feed = context.read<FeedController>();
    unawaited(feed.applyQuery(feed.query.toggleTopic(topic)));
  }

  void _clearTopics() {
    final FeedController feed = context.read<FeedController>();
    unawaited(feed.applyQuery(feed.query.copyWith(topics: const <ArticleTopic>{})));
  }

  @override
  Widget build(BuildContext context) {
    final FeedController feed = context.watch<FeedController>();
    final SourceRegistry registry = context.registry;
    final List<Article> articles = feed.articles;
    final bool hasArticles = articles.isNotEmpty;

    final List<Article> carouselItems =
        articles.where((Article a) => a.imageUrl != null).take(6).toList(growable: false);
    final bool showCarousel = carouselItems.length >= 3;
    final Set<String> carouselIds =
        showCarousel ? carouselItems.map((Article a) => a.id).toSet() : <String>{};

    final Article? lead = !showCarousel && hasArticles ? articles.first : null;
    final NewsSource? leadSource = lead == null ? null : registry.byId(lead.sourceId);
    final List<Article> river = !hasArticles
        ? const <Article>[]
        : showCarousel
            ? articles
                .where((Article a) => !carouselIds.contains(a.id))
                .toList(growable: false)
            : articles.skip(1).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: 96,
          color: context.colors.primary,
          backgroundColor: context.theme.colorScheme.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                toolbarHeight: 66,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleSpacing: 0,
                flexibleSpace: const _MastheadGlass(),
                title: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
                  child: Masthead(
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        GlassIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: context.strings.filterTitle,
                          badge: feed.query.sourceIds.isNotEmpty ||
                              feed.query.languages.isNotEmpty ||
                              feed.query.topics.isNotEmpty,
                          onTap: () => showFeedFilterSheet(context),
                        ),
                        const SizedBox(width: 8),
                        GlassIconButton(
                          icon: Icons.search_rounded,
                          tooltip: context.strings.searchTitle,
                          onTap: () => Navigator.of(context).push<void>(
                            editorialRoute<void>(const SearchScreen(), name: 'search'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (feed.lastError != null) _ErrorNote(message: feed.lastError!),
                  BreakingBanner(
                    articles: feed.breakingArticles,
                    onOpen: (Article article) => openArticle(context, article),
                  ),
                  if (!hasArticles && feed.isLoading)
                    const _LoadingState()
                  else if (!hasArticles)
                    _EmptyState(feed: feed, onRetry: _refresh)
                  else ...<Widget>[
                    const SizedBox(height: 6),
                    if (showCarousel)
                      RiseIn(
                        child: FeaturedCarousel(
                          articles: articles,
                          sourceFor: (Article a) => registry.byId(a.sourceId),
                          onOpen: (Article a) => openArticle(context, a),
                        ),
                      )
                    else if (lead != null)
                      RiseIn(
                        child: LeadStory(
                          article: lead,
                          source: leadSource,
                          onTap: () => openArticle(context, lead),
                          onOpenSource: leadSource == null
                              ? null
                              : () => openSource(context, leadSource),
                        ),
                      ),
                    const SizedBox(height: 8),
                    CategoryStrip(
                      selected: feed.query.topics,
                      onToggle: _toggleTopic,
                      onClear: _clearTopics,
                    ),
                    const SizedBox(height: 4),
                    _FeedBar(
                      following: feed.query.followedOnly,
                      onChanged: _setFollowing,
                      count: articles.length,
                      refreshing: feed.isRefreshing,
                      onRefresh: _refresh,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter + 4,
                        8,
                        Tokens.gutter,
                        0,
                      ),
                      child: _StatusLine(
                        status: _Status(
                          offline: feed.isOffline,
                          cached: feed.isShowingCached,
                          updated: feed.lastRefreshAt,
                        ),
                        refreshing: feed.isRefreshing,
                      ),
                    ),
                    if (river.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Tokens.gutter,
                          18,
                          Tokens.gutter,
                          4,
                        ),
                        child: Kicker(
                          feed.query.followedOnly
                              ? context.strings.followedPapers
                              : context.strings.latestNews,
                        ),
                      ),
                  ],
                ],
                ),
              ),
              // The river is a real sliver list, so a long feed only builds the
              // rows that are on screen — no eager Column of a hundred cards.
              if (river.isNotEmpty)
                SliverList.builder(
                  itemCount: river.length,
                  itemBuilder: (BuildContext context, int index) => NewsCard(
                    article: river[index],
                    source: registry.byId(river[index].sourceId),
                    index: index,
                    onTap: () => openArticle(context, river[index]),
                  ),
                ),
              if (river.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Center(
                      child: Text(
                        context.strings.feedEnd,
                        style: context.texts.labelSmall?.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 1.4,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The masthead's material: a real blur, a translucent wash and one hairline —
/// the only permanently pinned glass surface in the app.
class _MastheadGlass extends StatelessWidget {
  const _MastheadGlass();

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: Tokens.blurBar, sigmaY: Tokens.blurBar),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const <Color>[Color(0xE60E1013), Color(0xB30B0C0E)]
                  : const <Color>[Color(0xF2F3F1EE), Color(0xC7F3F1EE)],
            ),
            border: Border(
              bottom: BorderSide(
                color: (dark ? Tokens.nightHairline : Tokens.hairline)
                    .withValues(alpha: 0.8),
                width: 0.9,
              ),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The slim feed bar: a segmented All / Following control, the live count, a
/// refresh affordance and the honest freshness line, all in one glass strip.
class _FeedBar extends StatelessWidget {
  const _FeedBar({
    required this.following,
    required this.onChanged,
    required this.count,
    required this.refreshing,
    required this.onRefresh,
  });

  final bool following;
  final ValueChanged<bool> onChanged;
  final int count;
  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 6, Tokens.gutter, 0),
      child: Row(
        children: <Widget>[
          _Segment(following: following, onChanged: onChanged),
          const SizedBox(width: 10),
          if (count > 0)
            Text(
              '${BengaliText.toBengaliDigits(count)} '
              '${context.strings.articleCountShort}',
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          _RefreshButton(refreshing: refreshing, onRefresh: onRefresh),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.following, required this.onChanged});

  final bool following;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    final bool dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.62),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.10) : Tokens.hairline,
          width: 0.9,
        ),
      ),
      child: SizedBox(
        width: 156,
        height: 28,
        child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: motion.reduce ? Duration.zero : const Duration(milliseconds: 330),
            curve: Curves.easeOutBack,
            alignment: following ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 78,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Tokens.radiusPill),
                color: context.colors.primary,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SegmentTab(
                label: context.strings.all,
                active: !following,
                onTap: () => onChanged(false),
              ),
              _SegmentTab(
                label: context.strings.followingLabel,
                active: following,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: onTap,
      scale: 0.94,
      child: SizedBox(
        width: 78,
        height: 28,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: context.texts.labelSmall!.copyWith(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : context.colors.onSurfaceVariant,
            ),
            child: Text(label, maxLines: 1),
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.refreshing, required this.onRefresh});

  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: refreshing ? null : onRefresh,
      scale: 0.88,
      enabled: !refreshing,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: refreshing
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    color: context.colors.primary,
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: context.colors.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}

class _Status {
  const _Status({required this.offline, required this.cached, required this.updated});

  final bool offline;
  final bool cached;
  final DateTime? updated;
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.refreshing});

  final _Status status;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final String? updated = BengaliText.relative(
      status.updated,
      bengali: context.isBengali,
    );
    final String text = status.offline
        ? context.strings.offlineNotice
        : status.cached
            ? context.strings.cachedNotice
            : updated == null
                ? context.strings.neverUpdated
                : '${context.strings.lastUpdated}: $updated';
    final Color color =
        status.offline ? context.colors.error : context.colors.onSurfaceVariant;

    return Row(
      children: <Widget>[
        Icon(
          status.offline
              ? Icons.cloud_off_rounded
              : status.cached
                  ? Icons.history_rounded
                  : Icons.schedule_rounded,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelSmall?.copyWith(
              fontSize: 10,
              height: 1.3,
              color: color,
            ),
          ),
        ),
        if (refreshing)
          Text(
            '${context.strings.checking}…',
            style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
          ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, 0),
      child: GlassPanel(
        radius: Tokens.radiusMd,
        tone: GlassTone.subtle,
        blur: Tokens.blurSoft,
        shadow: false,
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 15, color: context.colors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: context.texts.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.45,
                  color: context.colors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholders shaped like the page: a hero block, a control card and rows.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 14, Tokens.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShimmerBox(height: 250, radius: Tokens.radiusLg),
          const SizedBox(height: 14),
          const ShimmerBox(height: 84, radius: Tokens.radiusLg),
          const SizedBox(height: 18),
          for (int i = 0; i < 4; i++) ...<Widget>[
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ShimmerBox(height: 9, width: 64),
                      SizedBox(height: 8),
                      ShimmerBox(height: 15),
                      SizedBox(height: 6),
                      ShimmerBox(height: 15, width: 170),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                ShimmerBox(height: 72, width: 72, radius: Tokens.radiusSm),
              ],
            ),
            const SizedBox(height: 16),
            const SoftRule(opacity: 0.6),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.feed, required this.onRetry});

  final FeedController feed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final bool offline = feed.isOffline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EmptyState(
          icon: offline ? Icons.cloud_off_rounded : Icons.article_outlined,
          title: context.strings.emptyFeedTitle,
          body: offline ? context.strings.offlineNotice : context.strings.emptyFeedBody,
          compact: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 0),
          child: Row(
            children: <Widget>[
              JellyButton(
                label: context.strings.retry,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                compact: true,
              ),
              const SizedBox(width: 8),
              JellyButton(
                label: context.strings.browseDirectory,
                filled: false,
                compact: true,
                onPressed: () => openSourceDirectory(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
