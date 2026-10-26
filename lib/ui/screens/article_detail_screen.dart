import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../core/utils/story_matcher.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
import '../../state/feed_controller.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/translation_sheet.dart';
import 'browser_screen.dart';

/// Reading surface for an aggregated story.
///
/// Only the headline, the excerpt the publisher put in its feed and a link are
/// shown. The full article is always read on the publisher's site.
///
/// The page is built as a printed column: a photograph, a serif headline, the
/// excerpt at reading size with generous leading, then the quiet actions. The
/// only chrome is the floating toolbar and the progress hairline under it.
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.related,
  });

  final Article article;
  final List<Article>? related;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  List<Article> _repositoryRelated = const <Article>[];
  bool _repositoryLookupPending = true;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFrame());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _afterFrame() async {
    if (!mounted) return;
    // Both look-ups happen before the first await so no BuildContext is used
    // across an asynchronous gap.
    final SavedController saved = context.read<SavedController>();
    final ArticleRepository repository = context.read<ArticleRepository>();
    try {
      await saved.recordHistory(widget.article);
    } catch (_) {
      // History persistence must not prevent Source Comparison from loading.
    }
    try {
      final List<Article> related =
          await repository.relatedCoverage(widget.article);
      if (mounted) setState(() => _repositoryRelated = related);
    } catch (_) {
      // The live controller index remains authoritative and can still update
      // this screen after a cache lookup failure.
    } finally {
      if (mounted) setState(() => _repositoryLookupPending = false);
    }
  }

  static List<Article> _mergeRelated(
    Article current,
    List<Article> candidates,
  ) {
    final Map<String, Article> byPublisher = <String, Article>{};
    final Set<String> urls = <String>{StoryMatcher.canonicalUrl(current.link)};
    for (final Article candidate in candidates) {
      final String url = StoryMatcher.canonicalUrl(candidate.link);
      if (candidate.id == current.id ||
          candidate.sourceId == current.sourceId ||
          !urls.add(url)) {
        continue;
      }
      byPublisher.putIfAbsent(candidate.sourceId, () => candidate);
    }
    return byPublisher.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final Article article = widget.article;
    final SourceRegistry registry = context.registry;
    final NewsSource? source = registry.byId(article.sourceId);
    final FeedController feed = context.watch<FeedController>();
    final List<Article> liveRelated = feed.relatedFor(article);
    final List<Article> related = _mergeRelated(
      article,
      <Article>[
        ...?widget.related,
        ...liveRelated,
        ..._repositoryRelated,
      ],
    );
    final bool comparisonPending = related.isEmpty &&
        (_repositoryLookupPending ||
            !feed.comparisonIndexReady ||
            feed.isLoading ||
            feed.isRefreshing);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: ScrollConfiguration(
          behavior: const _ArticleScrollBehavior(),
          child: CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                toolbarHeight: 58,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: context.theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                leadingWidth: Tokens.gutter + 42,
                leading: Padding(
                  padding:
                      const EdgeInsetsDirectional.only(start: Tokens.gutter),
                  child: Center(
                    child: GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.strings.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
                actions: <Widget>[
                  BookmarkAction(article: article, dense: true),
                  const SizedBox(width: 4),
                  GlassIconButton(
                    icon: Icons.translate_rounded,
                    tooltip: context.strings.translateAction,
                    onTap: () => showTranslationSheet(
                      context,
                      text: <String>[
                        article.title,
                        if ((article.excerpt ?? '').isNotEmpty)
                          article.excerpt!,
                      ].join(' '),
                    ),
                  ),
                  const SizedBox(width: Tokens.gutter),
                ],
              ),
              SliverToBoxAdapter(
                child: _ArticleBody(
                  article: article,
                  source: source,
                  related: related,
                  comparisonPending: comparisonPending,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleScrollBehavior extends MaterialScrollBehavior {
  const _ArticleScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.article,
    required this.source,
    required this.related,
    required this.comparisonPending,
  });

  final Article article;
  final NewsSource? source;
  final List<Article> related;
  final bool comparisonPending;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String sourceName =
        source?.localizedName(bengali: bengali) ?? article.sourceId;
    final SourceRegistry registry = context.registry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (article.imageUrl != null)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Tokens.gutter, 2, Tokens.gutter, 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: RemoteImage(
                  url: article.imageUrl!,
                  decodeWidth: MediaQuery.sizeOf(context).width,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SourceLine(
                article: article,
                source: source,
                sourceName: sourceName,
              ),
              const SizedBox(height: 14),
              Text(
                article.title,
                style: context.texts.displaySmall?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 26,
                  height: 1.38,
                  letterSpacing: -0.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (article.author != null) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        article.author!,
                        style: context.texts.labelSmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const SoftRule(inset: 0, thickness: 0.8),
              const SizedBox(height: 18),
              if ((article.excerpt ?? '').isNotEmpty) ...<Widget>[
                Text(
                  article.excerpt!,
                  style: context.texts.bodyLarge?.copyWith(
                    fontFamily: Tokens.serif,
                    fontSize: 16.8,
                    height: 1.92,
                    letterSpacing: 0.02,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _ExcerptNote(text: context.strings.excerptNotice),
              const SizedBox(height: 20),
              JellyButton(
                key: const ValueKey<String>('read-full-story'),
                label: context.strings.readInApp,
                icon: Icons.menu_book_rounded,
                filled: true,
                expand: true,
                onPressed: () => openInBrowser(
                  context,
                  url: article.link,
                  title: article.title,
                  source: source,
                  article: article,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                key: const ValueKey<String>('source-comparison-section'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.strings.relatedCoverage,
                    style: context.texts.labelLarge?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (related.isNotEmpty) ...<Widget>[
                    Text(
                      context.isBengali
                          ? 'আরও ${related.length}টি সংবাদমাধ্যমে'
                          : 'Also from ${related.length} other ${related.length == 1 ? 'source' : 'sources'}',
                      style: context.texts.labelMedium?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.isBengali
                          ? 'শিরোনামের মিল; স্বাধীন সত্যতা যাচাই নয়। উপলভ্য উৎসেই সীমিত।'
                          : 'Headline match, not independent verification. Limited to available sources.',
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 9.5,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final Article other in related)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RelatedRow(
                          article: other,
                          source: registry.byId(other.sourceId),
                        ),
                      ),
                  ] else
                    Row(
                      key: ValueKey<String>(
                        comparisonPending
                            ? 'source-comparison-loading'
                            : 'source-comparison-empty',
                      ),
                      children: <Widget>[
                        if (comparisonPending) ...<Widget>[
                          Icon(
                            Icons.manage_search_rounded,
                            size: 16,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            comparisonPending
                                ? context.strings.relatedCoverageLoading
                                : context.strings.relatedCoverageEmpty,
                            style: context.texts.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ),
              if (source != null)
                _SourceFooter(
                  key: const ValueKey<String>('publisher-identity'),
                  source: source!,
                ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({
    required this.article,
    required this.source,
    required this.sourceName,
  });

  final Article article;
  final NewsSource? source;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    return JellySurface(
      scale: 0.99,
      onTap: source == null ? null : () => openSource(context, source!),
      child: Row(
        children: <Widget>[
          if (source != null) ...<Widget>[
            SourceAvatar(source: source!, size: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sourceName,
                  style: context.texts.labelLarge?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    if (article.breaking) ...<Widget>[
                      Text(
                        bengali ? 'ব্রেকিং · ' : 'BREAKING · ',
                        style: context.texts.labelSmall?.copyWith(
                          color: Tokens.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        article.publishedAt == null
                            ? context.strings.noPublicationDate
                            : BengaliText.dateTime(
                                article.publishedAt!,
                                bengali: bengali,
                              ),
                        style:
                            context.texts.labelSmall?.copyWith(fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (source != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _ExcerptNote extends StatelessWidget {
  const _ExcerptNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: Tokens.radiusSm,
      blur: 0,
      elevation: 0,
      border: true,
      sheen: false,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.texts.labelSmall?.copyWith(
                height: 1.55,
                fontSize: 10.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.article, required this.source});

  final Article article;
  final NewsSource? source;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    return JellySurface(
      onTap: () => openArticle(context, article),
      scale: 0.99,
      child: GlassPanel(
        radius: Tokens.radiusSm,
        blur: 0,
        elevation: 0.2,
        sheen: false,
        padding: const EdgeInsets.all(11),
        child: Row(
          children: <Widget>[
            if (article.imageUrl != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusXs),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: RemoteImage(
                    url: article.imageUrl!,
                    decodeWidth: 58,
                    fade: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ] else if (source != null) ...<Widget>[
              SourceAvatar(source: source!, size: 30),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(
                      fontFamily: Tokens.serif,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${source?.localizedName(bengali: bengali) ?? article.sourceId} · '
                    '${BengaliText.relative(article.publishedAt, bengali: bengali) ?? ''}',
                    style: context.texts.labelSmall?.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    article.link,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 8.8,
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({super.key, required this.source});

  final NewsSource source;

  @override
  Widget build(BuildContext context) {
    final bool following =
        context.watch<SettingsController>().isFollowing(source.id);
    return GlassPanel(
      radius: Tokens.radiusMd,
      blur: Tokens.blurSoft,
      elevation: 0.5,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SourceAvatar(source: source, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.localizedName(bengali: context.isBengali),
                      style: context.texts.titleSmall?.copyWith(
                        fontFamily: Tokens.serif,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      publicationMeta(source, bengali: context.isBengali),
                      style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GlassChip(
                label: following
                    ? context.strings.followingLabel
                    : context.strings.follow,
                dense: true,
                selected: following,
                icon: following ? Icons.check_rounded : Icons.add_rounded,
                onTap: () =>
                    context.read<SettingsController>().toggleFollow(source.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
