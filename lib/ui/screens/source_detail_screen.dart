import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../data/services/article_repository.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../services/link_launcher.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial.dart';
import '../widgets/editorial_story.dart';
import 'browser_screen.dart';

/// Publication page: identity, actions, feed status, cached headlines and
/// e-paper links. Every action shown here is one the app can actually perform.
///
/// The masthead belongs to the publication, not the app: its monogram leads, the
/// name is set in the serif, and the app's red appears only on the action.
class SourceDetailScreen extends StatefulWidget {
  const SourceDetailScreen({super.key, required this.source});

  final NewsSource source;

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  List<Article> _articles = const <Article>[];
  bool _loading = true;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Article> articles = await context
          .read<ArticleRepository>()
          .articlesForSource(widget.source.id, limit: 25);
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchNow() async {
    setState(() => _fetching = true);
    await context.read<FeedController>().refreshSource(widget.source.id);
    await _load();
    if (mounted) setState(() => _fetching = false);
  }

  @override
  Widget build(BuildContext context) {
    final NewsSource source = widget.source;
    final bool bengali = context.isBengali;
    final SettingsController settings = context.watch<SettingsController>();
    final FeedController feed = context.watch<FeedController>();
    final SourceHealth? health = feed.healthFor(source.id);
    final bool following = settings.isFollowing(source.id);
    final List<EpaperEdition> editions = context.registry.epapersFor(source.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 4),
                child: Row(
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.strings.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    GlassIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: context.strings.sharePublication,
                      onTap: () => LinkLauncher.share(
                        '${source.localizedName(bengali: bengali)} (${source.name})\n${source.website}',
                        subject: source.name,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassIconButton(
                      icon: source.hasFeed
                          ? Icons.refresh_rounded
                          : Icons.public_rounded,
                      tooltip: source.hasFeed
                          ? context.strings.refresh
                          : context.strings.openWebsite,
                      onTap: _fetching
                          ? null
                          : () {
                              if (source.hasFeed) {
                                _fetchNow();
                              } else {
                                openInBrowser(
                                  context,
                                  url: source.website,
                                  title: source.localizedName(bengali: bengali),
                                  source: source,
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 130),
                  children: <Widget>[
                    _Identity(
                      source: source,
                      health: health,
                      bengali: bengali,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter,
                        16,
                        Tokens.gutter,
                        6,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: JellyButton(
                              label: context.strings.openMainWebsite,
                              icon: Icons.public_rounded,
                              filled: true,
                              compact: true,
                              onPressed: () => openInBrowser(
                                context,
                                url: source.website,
                                title: source.localizedName(bengali: bengali),
                                source: source,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GlassChip(
                            label: following
                                ? context.strings.followingLabel
                                : context.strings.follow,
                            icon: following
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            selected: following,
                            onTap: () => settings.toggleFollow(source.id),
                          ),
                        ],
                      ),
                    ),
                    if (source.hasEpaper)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Tokens.gutter,
                          6,
                          Tokens.gutter,
                          0,
                        ),
                        child: GlassChip(
                          label: context.strings.openEpaper,
                          icon: Icons.menu_book_outlined,
                          onTap: () => openUrlFeedback(context, source.epaperUrl),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter,
                        22,
                        Tokens.gutter,
                        10,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Kicker(context.strings.latestHeadlines)),
                          if (source.hasFeed)
                            JellySurface(
                              onTap: _fetching ? null : _fetchNow,
                              scale: 0.9,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: _fetching
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                        ),
                                      )
                                    : Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.sync_rounded,
                                            size: 14,
                                            color: context.colors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.strings.refresh,
                                            style:
                                                context.texts.labelSmall?.copyWith(
                                              fontSize: 10.5,
                                              color: context.colors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_loading)
                      const ArticleSkeleton(count: 3)
                    else if (_articles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Tokens.gutter,
                          0,
                          Tokens.gutter,
                          10,
                        ),
                        child: GlassPanel(
                          radius: Tokens.radiusMd,
                          blur: 0,
                          elevation: 0.3,
                          sheen: false,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: <Widget>[
                              Text(
                                context.strings.noHeadlinesYet,
                                style: context.texts.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              if (source.hasFeed)
                                JellyButton(
                                  label: context.strings.fetchHeadlines,
                                  icon: Icons.download_rounded,
                                  compact: true,
                                  onPressed: _fetchNow,
                                )
                              else
                                JellyButton(
                                  label: context.strings.openWebsite,
                                  icon: Icons.public_rounded,
                                  compact: true,
                                  onPressed: () => openInBrowser(
                                    context,
                                    url: source.website,
                                    title: source.localizedName(bengali: bengali),
                                    source: source,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final Article article in _articles.take(8))
                        NewsCard(
                          article: article,
                          source: source,
                          onTap: () => openArticle(context, article),
                        ),
                    if (_articles.length > 8)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Tokens.gutter,
                          8,
                          Tokens.gutter,
                          0,
                        ),
                        child: Center(
                          child: GlassChip(
                            label: context.strings.viewAll,
                            icon: Icons.expand_more_rounded,
                            onTap: () => openArticleList(
                              context,
                              title: source.localizedName(bengali: bengali),
                              sourceIds: <String>{source.id},
                            ),
                          ),
                        ),
                      ),
                    if (editions.isNotEmpty) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Tokens.gutter,
                          26,
                          Tokens.gutter,
                          10,
                        ),
                        child: Kicker(context.strings.epaperSectionTitle),
                      ),
                      for (final EpaperEdition edition in editions)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Tokens.gutter,
                            0,
                            Tokens.gutter,
                            8,
                          ),
                          child: JellySurface(
                            onTap: () => openUrlFeedback(context, edition.url),
                            scale: 0.99,
                            child: GlassPanel(
                              radius: Tokens.radiusSm,
                              blur: 0,
                              elevation: 0.2,
                              sheen: false,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.menu_book_outlined,
                                    size: 18,
                                    color: context.colors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          edition.localizedName(bengali: bengali),
                                          style: context.texts.titleSmall?.copyWith(
                                            fontFamily: Tokens.serif,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        Text(
                                          context.strings.epaperNote,
                                          style: context.texts.labelSmall
                                              ?.copyWith(fontSize: 10),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 15,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter,
                        22,
                        Tokens.gutter,
                        0,
                      ),
                      child: Eyebrow(context.strings.aboutPublication),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter,
                        10,
                        Tokens.gutter,
                        0,
                      ),
                      child: GlassPanel(
                        radius: Tokens.radiusMd,
                        blur: 0,
                        elevation: 0.3,
                        sheen: false,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _InfoRow(
                              label: context.strings.verifiedWebsite,
                              value: source.website,
                            ),
                            _InfoRow(
                              label: context.strings.filterCategory,
                              value: Labels.type(source.type, bengali: bengali),
                            ),
                            _InfoRow(
                              label: context.strings.filterLanguage,
                              value:
                                  Labels.language(source.language, bengali: bengali),
                            ),
                            if (source.division != null)
                              _InfoRow(
                                label: context.strings.filterDivision,
                                value:
                                    '${source.division}${source.district != null ? ' · ${source.district}' : ''}',
                              ),
                            _InfoRow(
                              label: context.strings.feedState,
                              value: Labels.feedClaim(
                                source.feedClaim,
                                bengali: bengali,
                              ),
                            ),
                            if (source.lastVerifiedAt != null)
                              _InfoRow(
                                label: context.strings.verifiedOn,
                                value: source.lastVerifiedAt!,
                              ),
                            _InfoRow(
                              label: context.strings.lastChecked,
                              value: health?.lastCheckedAt == null
                                  ? context.strings.never
                                  : BengaliText.dateTime(
                                      health!.lastCheckedAt!,
                                      bengali: bengali,
                                    ),
                            ),
                            if (source.notes.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                source.notes,
                                style: context.texts.bodySmall?.copyWith(
                                  height: 1.6,
                                ),
                              ),
                            ],
                            if (source.categories
                                .contains(SourceCategory.broadcast)) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                context.strings.broadcastNotice,
                                style: context.texts.labelSmall?.copyWith(
                                  color: Tokens.danger,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.source,
    required this.health,
    required this.bengali,
  });

  final NewsSource source;
  final SourceHealth? health;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    final String? secondary = source.secondaryName(bengali: bengali);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 6, Tokens.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Colors.white.withValues(alpha: context.isDark ? 0.22 : 0.9),
                      Colors.white.withValues(alpha: context.isDark ? 0.04 : 0.35),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: context.isDark ? 0.14 : 0.8),
                    width: 0.9,
                  ),
                  boxShadow: Tokens.shadow(context, lift: 0.8),
                ),
                child: SourceAvatar(source: source, size: 62),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.localizedName(bengali: bengali),
                      style: context.texts.headlineSmall?.copyWith(
                        fontFamily: Tokens.serif,
                        fontSize: 22,
                        height: 1.25,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (secondary != null)
                      Text(
                        secondary,
                        style: context.texts.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      publicationMeta(source, bengali: bengali),
                      style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final SourceCategory category in source.categories)
                _Tag(
                  icon: Labels.categoryIcon(category),
                  label: Labels.category(category, bengali: bengali),
                ),
              _Tag(
                icon: source.hasFeed ? Icons.rss_feed_rounded : Icons.public_rounded,
                label: source.hasFeed
                    ? Labels.feedHealth(
                        health?.status ?? SourceHealthStatus.unknown,
                        bengali: bengali,
                      )
                    : context.strings.feedNotAvailable,
                accent: health?.status == SourceHealthStatus.ok,
              ),
              if (source.status == SourceStatus.needsReview)
                _Tag(
                  icon: Icons.error_outline_rounded,
                  label: context.strings.needsReview,
                  warning: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.label,
    this.accent = false,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool accent;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Color color = warning
        ? Tokens.danger
        : accent
            ? (context.isDark ? Tokens.accentNight : Tokens.accent)
            : context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.5,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.5,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
