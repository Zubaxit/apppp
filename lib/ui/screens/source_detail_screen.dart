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
import '../../theme/app_theme.dart';
import '../helpers/app_nav.dart';
import '../services/link_launcher.dart';
import '../widgets/article_card.dart';
import '../widgets/common.dart';

/// Publication page: identity, actions, feed status, cached headlines and
/// e-paper links. Every action shown here is one the app can actually perform.
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
      final List<Article> articles =
          await context.read<ArticleRepository>().articlesForSource(widget.source.id, limit: 25);
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
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            actions: <Widget>[
              IconButton(
                tooltip: context.strings.sharePublication,
                onPressed: () => LinkLauncher.share(
                  '${source.localizedName(bengali: bengali)} (${source.name})\n${source.website}',
                  subject: source.name,
                ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SourceAvatar(source: source, size: 62),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              source.localizedName(bengali: bengali),
                              style: context.texts.headlineSmall?.copyWith(fontSize: 21),
                            ),
                            if (source.secondaryName(bengali: bengali) != null)
                              Text(
                                source.secondaryName(bengali: bengali)!,
                                style: context.texts.bodySmall,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              publicationMeta(source, bengali: bengali),
                              style: context.texts.labelSmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => openUrlFeedback(context, source.website),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: context.colors.primary,
                                foregroundColor: context.colors.onPrimary,
                              ),
                              icon: const Icon(Icons.public_rounded, size: 17),
                              label: Text(
                                context.strings.openWebsite,
                                style: context.texts.labelLarge?.copyWith(
                                  color: context.colors.onPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => settings.toggleFollow(source.id),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: following
                                      ? context.colors.primary
                                      : context.colors.outlineVariant,
                                ),
                              ),
                              icon: Icon(
                                following
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 17,
                                color: context.colors.primary,
                              ),
                              label: Text(
                                following
                                    ? context.strings.followingLabel
                                    : context.strings.follow,
                                style: context.texts.labelLarge?.copyWith(
                                  fontSize: 12.5,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (source.hasEpaper) ...<Widget>[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => openUrlFeedback(context, source.epaperUrl),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: context.colors.outlineVariant),
                            ),
                            icon: const Icon(Icons.menu_book_outlined, size: 17),
                            label: Text(
                              context.strings.openEpaper,
                              style: context.texts.labelLarge?.copyWith(fontSize: 12.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: context.strings.latestHeadlines,
                  actionLabel: source.hasFeed ? context.strings.refresh : null,
                  onAction: source.hasFeed && !_fetching ? _fetchNow : null,
                ),
                if (_fetching)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_loading)
                  const ArticleSkeleton(count: 2)
                else if (_articles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            context.strings.noHeadlinesYet,
                            style: context.texts.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          if (source.hasFeed)
                            OutlinedButton.icon(
                              onPressed: _fetchNow,
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: Text(context.strings.fetchHeadlines),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => openUrlFeedback(context, source.website),
                              icon: const Icon(Icons.public_rounded, size: 16),
                              label: Text(context.strings.openWebsite),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._articles.take(8).map((Article article) => Column(
                        children: <Widget>[
                          ArticleCard(
                            article: article,
                            source: source,
                            variant: ArticleCardVariant.compact,
                            onTap: () => openArticle(context, article),
                          ),
                          Divider(
                            height: 0.6,
                            thickness: 0.6,
                            indent: 20,
                            endIndent: 20,
                            color: context.colors.outlineVariant,
                          ),
                        ],
                      )),
                if (_articles.length > 8)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => openArticleList(
                          context,
                          title: source.localizedName(bengali: bengali),
                          sourceIds: <String>{source.id},
                        ),
                        child: Text(context.strings.viewAll),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                if (editions.isNotEmpty) ...<Widget>[
                  SectionHeader(title: context.strings.epaperSectionTitle),
                  ...editions.map((EpaperEdition edition) => ListTile(
                        leading: Icon(Icons.menu_book_outlined, color: context.colors.primary),
                        title: Text(
                          edition.localizedName(bengali: bengali),
                          style: context.texts.titleSmall,
                        ),
                        subtitle: Text(context.strings.epaperNote,
                            style: context.texts.labelSmall, maxLines: 2),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => openUrlFeedback(context, edition.url),
                      )),
                  const SizedBox(height: 10),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(context.strings.aboutPublication, style: context.texts.titleSmall),
                        const SizedBox(height: 8),
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
                          value: Labels.language(source.language, bengali: bengali),
                        ),
                        if (source.division != null)
                          _InfoRow(
                            label: context.strings.filterDivision,
                            value:
                                '${source.division}${source.district != null ? ' · ${source.district}' : ''}',
                          ),
                        _InfoRow(
                          label: context.strings.feedState,
                          value: Labels.feedClaim(source.feedClaim, bengali: bengali),
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
                              : BengaliText.dateTime(health!.lastCheckedAt!, bengali: bengali),
                        ),
                        if ((source.notes).isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(source.notes, style: context.texts.bodySmall),
                        ],
                        if (source.categories.contains(SourceCategory.broadcast)) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            context.strings.broadcastNotice,
                            style: context.texts.labelSmall?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 34),
              ],
            ),
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
        ? context.colors.error
        : accent
            ? (context.isDark ? AppColors.mint : AppColors.brandGreen)
            : context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: color,
              fontSize: 10.5,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(label, style: context.texts.labelSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: context.texts.labelSmall?.copyWith(color: context.colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
