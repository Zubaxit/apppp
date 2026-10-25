import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import '../widgets/brand.dart';
import '../widgets/editorial.dart';
import '../widgets/editorial_story.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/feed_filter_sheet.dart';
import '../widgets/feed_widgets.dart';
import 'search_screen.dart';

/// The front page.
///
/// Composition: a frosted masthead, a featured rail drawn from real articles,
/// the All / Following switch, a compact topic rail, then a rule-separated river
/// of headlines. No cards, no shadows on content, no invented stories — every
/// item here came out of a verified publisher feed.
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

  Row _mastheadActions(BuildContext context, FeedController feed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _GlassAction(
          icon: Icons.tune_rounded,
          tooltip: context.strings.filterTitle,
          badge: feed.query.sourceIds.isNotEmpty ||
              feed.query.languages.isNotEmpty ||
              feed.query.topics.isNotEmpty,
          onTap: () => showFeedFilterSheet(context),
        ),
        const SizedBox(width: 6),
        _GlassAction(
          icon: Icons.search_rounded,
          tooltip: context.strings.searchTitle,
          onTap: () => Navigator.of(context).push<void>(
            editorialRoute<void>(const SearchScreen(), name: 'search'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final FeedController feed = context.watch<FeedController>();
    final SourceRegistry registry = context.registry;
    final List<Article> articles = feed.articles;
    final bool hasArticles = articles.isNotEmpty;

    // The rail only earns its place when there is real material for it.
    final List<Article> carouselItems =
        articles.where((Article a) => a.imageUrl != null).take(5).toList(growable: false);
    final bool showCarousel = carouselItems.length >= 3;
    final Set<String> carouselIds =
        showCarousel ? carouselItems.map((Article a) => a.id).toSet() : <String>{};

    final Article? lead = !showCarousel && hasArticles ? articles.first : null;
    final NewsSource? leadSource = lead == null ? null : registry.byId(lead.sourceId);
    final List<Article> river = !hasArticles
        ? const <Article>[]
        : showCarousel
            ? articles.where((Article a) => !carouselIds.contains(a.id)).toList(growable: false)
            : articles.skip(1).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 84,
        color: context.colors.primary,
        backgroundColor: context.theme.colorScheme.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              toolbarHeight: 70,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              flexibleSpace: const _GlassBackdrop(),
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Masthead(trailing: _mastheadActions(context, feed)),
                    ),
                    if (feed.isRefreshing)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 8),
                        child: _RefreshingDot(),
                      ),
                  ],
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
                    _FeedControls(
                      following: feed.query.followedOnly,
                      onChanged: _setFollowing,
                      count: articles.length,
                      onRefresh: _refresh,
                      refreshing: feed.isRefreshing,
                    ),
                    _StatusLine(feed: feed),
                    TopicRail(
                      selected: feed.query.topics,
                      onToggle: _toggleTopic,
                      onClear: _clearTopics,
                    ),
                    if (river.isNotEmpty) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 18, Tokens.gutter, 2),
                        child: Kicker(
                          feed.query.followedOnly
                              ? context.strings.followedPapers
                              : context.strings.latestNews,
                        ),
                      ),
                      for (int i = 0; i < river.length; i++)
                        RiseIn(
                          index: i + 1,
                          child: StoryRow(
                            article: river[i],
                            source: registry.byId(river[i].sourceId),
                            onTap: () => openArticle(context, river[i]),
                            last: i == river.length - 1,
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                BookmarkAction(
                                  article: river[i],
                                  size: 18,
                                  dense: true,
                                  showSnack: false,
                                ),
                                ShareAction(article: river[i], size: 17, dense: true),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 26),
                      Center(
                        child: Text(
                          context.strings.feedEnd,
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 120),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted backdrop for the pinned masthead: real blur, a translucent fill and
/// a single hairline at the bottom edge. The blur is clipped to the bar so it
/// never smears the content below it.
class _GlassBackdrop extends StatelessWidget {
  const _GlassBackdrop();

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color base = dark ? Tokens.glassDark : Tokens.paper;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: base.withValues(alpha: dark ? 0.70 : 0.76),
            border: Border(
              bottom: BorderSide(
                color: (dark ? Tokens.nightHairline : Tokens.hairline)
                    .withValues(alpha: 0.9),
                width: 0.8,
              ),
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A two-pixel sweeping mark while a manual refresh runs: quieter than a
/// spinner in the masthead, and it stops when the refresh does.
class _RefreshingDot extends StatelessWidget {
  const _RefreshingDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 1.6,
        color: context.colors.primary,
      ),
    );
  }
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? Tokens.nightRaised : Tokens.paperRaised.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: dark ? Tokens.nightHairline : Tokens.hairline,
              width: 0.8,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Icon(icon, size: 18, color: context.colors.onSurface),
              if (badge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "All / Following" as quiet text with a rule under the active choice, plus the
/// live article count and a manual refresh.
class _FeedControls extends StatelessWidget {
  const _FeedControls({
    required this.following,
    required this.onChanged,
    required this.count,
    required this.onRefresh,
    required this.refreshing,
  });

  final bool following;
  final ValueChanged<bool> onChanged;
  final int count;
  final Future<void> Function() onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool active, VoidCallback onTap) {
      return Pressable(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Text(
                label,
                style: context.texts.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active
                      ? context.colors.onSurface
                      : context.colors.onSurfaceVariant,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 2,
              width: active ? 24 : 0,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 10, Tokens.gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          tab(context.strings.all, !following, () => onChanged(false)),
          const SizedBox(width: 18),
          tab(context.strings.followingLabel, following, () => onChanged(true)),
          const Spacer(),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '${BengaliText.toBengaliDigits(count)} ${context.strings.articleCountShort}',
                style: context.texts.labelSmall?.copyWith(
                  fontSize: 10.5,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Pressable(
            onTap: refreshing ? null : onRefresh,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 2),
              child: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: refreshing
                    ? context.colors.onSurfaceVariant.withValues(alpha: 0.4)
                    : context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Honest freshness line: last successful update, or a cached/offline note.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.feed});

  final FeedController feed;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String? updated = BengaliText.relative(feed.lastRefreshAt, bengali: bengali);
    final bool offline = feed.isOffline;
    final bool cached = feed.isShowingCached;

    final String text = offline
        ? context.strings.offlineNotice
        : cached
            ? context.strings.cachedNotice
            : updated == null
                ? context.strings.neverUpdated
                : '${context.strings.lastUpdated}: $updated';

    final Color color =
        offline ? context.colors.error : context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 0),
      child: Row(
        children: <Widget>[
          Icon(
            offline
                ? Icons.cloud_off_rounded
                : cached
                    ? Icons.history_rounded
                    : Icons.schedule_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.8,
                height: 1.35,
                color: color,
              ),
            ),
          ),
          if (feed.isRefreshing)
            Text(
              '${context.strings.checking}…',
              style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
            ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 10, Tokens.gutter, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: context.colors.error.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 16, color: context.colors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: context.texts.bodySmall?.copyWith(
                  fontSize: 11.5,
                  height: 1.4,
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

/// Placeholders shaped like the front page, not a spinner: the masthead band,
/// the featured image and two text blocks. Static by default (see
/// [SkeletonBlock]) so an idle screen costs nothing.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 22, Tokens.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SkeletonBlock(height: 11, width: 88),
          const SizedBox(height: 12),
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonBlock(height: double.infinity, radius: Tokens.radiusSm),
          ),
          const SizedBox(height: 14),
          const SkeletonBlock(height: 9, width: 72),
          const SizedBox(height: 10),
          const SkeletonBlock(height: 22),
          const SizedBox(height: 8),
          const SkeletonBlock(height: 22, width: 220),
          const SizedBox(height: 22),
          const FadingRule(),
          for (int i = 0; i < 4; i++) ...<Widget>[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SkeletonBlock(height: 9, width: 66),
                      SizedBox(height: 8),
                      SkeletonBlock(height: 15),
                      SizedBox(height: 6),
                      SkeletonBlock(height: 15, width: 180),
                      SizedBox(height: 7),
                      SkeletonBlock(height: 9, width: 120),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const SkeletonBlock(height: 66, width: 66, radius: 3),
              ],
            ),
            const SizedBox(height: 18),
            const FadingRule(inset: 0),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 40, Tokens.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            offline ? Icons.cloud_off_rounded : Icons.article_outlined,
            size: 26,
            color: context.colors.primary,
          ),
          const SizedBox(height: 14),
          Text(
            context.strings.emptyFeedTitle,
            style: context.texts.headlineSmall?.copyWith(
              fontFamily: Tokens.serif,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            offline ? context.strings.offlineNotice : context.strings.emptyFeedBody,
            style: context.texts.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: Text(context.strings.retry),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => openSourceDirectory(context),
                child: Text(context.strings.browseDirectory),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
