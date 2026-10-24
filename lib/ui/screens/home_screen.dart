import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/editorial.dart';
import '../widgets/editorial_story.dart';
import '../widgets/feed_filter_sheet.dart';
import 'search_screen.dart';

/// The front page.
///
/// Composition rules: one lead story, then a rule-separated river of headlines.
/// No cards, no shadows on content, no rounded blobs — the page reads like a
/// printed front page that happens to scroll.
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

  @override
  Widget build(BuildContext context) {
    final FeedController feed = context.watch<FeedController>();
    final SourceRegistry registry = context.registry;
    final List<Article> articles = feed.articles;
    final bool hasArticles = articles.isNotEmpty;
    final Article? lead = hasArticles ? articles.first : null;
    final NewsSource? leadSource = lead == null ? null : registry.byId(lead.sourceId);
    final List<Article> river = hasArticles ? articles.skip(1).toList() : const <Article>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 90,
        color: context.colors.primary,
        backgroundColor: context.theme.colorScheme.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _MastheadDelegate(
                child: Masthead(
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _GlassAction(
                        icon: Icons.tune_rounded,
                        tooltip: context.strings.filterTitle,
                        badge: feed.query.sourceIds.isNotEmpty ||
                            feed.query.languages.isNotEmpty,
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
                  ),
                ),
                refreshing: feed.isRefreshing,
                onRefresh: _refresh,
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FeedControls(
                    following: feed.query.followedOnly,
                    onChanged: _setFollowing,
                    count: articles.length,
                    onRefresh: _refresh,
                  ),
                  _StatusLine(feed: feed),
                  if (feed.lastError != null) _ErrorNote(message: feed.lastError!),
                  if (!hasArticles && feed.isLoading)
                    const _LoadingState()
                  else if (!hasArticles)
                    _EmptyState(feed: feed, onRetry: _refresh)
                  else ...<Widget>[
                    if (lead != null)
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 22, Tokens.gutter, 0),
                      child: Kicker(context.strings.latestNews),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < river.length; i++)
                      RiseIn(
                        index: i + 1,
                        child: StoryRow(
                          article: river[i],
                          source: registry.byId(river[i].sourceId),
                          onTap: () => openArticle(context, river[i]),
                          last: i == river.length - 1,
                        ),
                      ),
                    if (river.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 28),
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

/// Pinned masthead with a frosted backdrop once content scrolls beneath it.
class _MastheadDelegate extends SliverPersistentHeaderDelegate {
  const _MastheadDelegate({
    required this.child,
    required this.refreshing,
    required this.onRefresh,
  });

  final Widget child;
  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  double get minExtent => 76;

  @override
  double get maxExtent => 76;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return GlassBar(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 8),
      child: Row(
        children: <Widget>[
          Expanded(child: child),
          if (refreshing)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 6),
              child: SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MastheadDelegate old) =>
      old.refreshing != refreshing || old.child != child;
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
            color: dark ? Tokens.nightRaised : Tokens.paperSunken,
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
                  right: -3,
                  top: -3,
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

/// "All / Following" as quiet text with a rule underneath the active choice.
class _FeedControls extends StatelessWidget {
  const _FeedControls({
    required this.following,
    required this.onChanged,
    required this.count,
    required this.onRefresh,
  });

  final bool following;
  final ValueChanged<bool> onChanged;
  final int count;
  final Future<void> Function() onRefresh;

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
            Container(
              height: 2,
              width: 22,
              decoration: BoxDecoration(
                color: active ? context.colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 10, Tokens.gutter, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          tab(context.strings.all, !following, () => onChanged(false)),
          const SizedBox(width: 18),
          tab(context.strings.followingLabel, following, () => onChanged(true)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              count == 0
                  ? ''
                  : '${BengaliText.toBengaliDigits(count)} '
                      '${context.strings.articleCountShort}',
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.5,
                color: context.colors.onSurfaceVariant,
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

    final Color color = offline
        ? context.colors.error
        : cached
            ? context.colors.onSurfaceVariant
            : context.colors.onSurfaceVariant;

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
          color: context.colors.error.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: context.colors.error.withValues(alpha: 0.25), width: 0.8),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 24, Tokens.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < 5; i++) ...<Widget>[
            Container(
              height: 11,
              width: i.isEven ? 96 : 78,
              decoration: BoxDecoration(
                color: context.colors.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: i == 0 ? 22 : 17,
              decoration: BoxDecoration(
                color: context.colors.onSurface.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: i == 0 ? 22 : 17,
              width: MediaQuery.sizeOf(context).width * (i == 0 ? 0.62 : 0.45),
              decoration: BoxDecoration(
                color: context.colors.onSurface.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Hairline(),
            const SizedBox(height: 20),
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
            style: context.texts.headlineSmall?.copyWith(fontSize: 21),
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
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
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
