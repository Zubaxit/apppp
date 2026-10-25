import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
import '../../services/link_service.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../services/link_launcher.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial.dart';
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
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  List<Article> _related = const <Article>[];
  bool _loadingRelated = true;

  final ScrollController _scroll = ScrollController();

  /// Reading progress is a value, not widget state.
  ///
  /// It used to be a field updated through setState on every scroll tick, which
  /// rebuilt the article column — headline, excerpt, photograph, actions — once
  /// per frame while the reader moved. A notifier repaints the 2 px rule and
  /// leaves the page alone.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFrame());
  }

  /// Reading progress is derived from the scroll position only, so it never
  /// rebuilds the article text itself.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double max = _scroll.position.maxScrollExtent;
    final double value = max <= 0 ? 1 : (_scroll.offset / max).clamp(0.0, 1.0);
    if ((value - _progress.value).abs() < 0.004 && value != 1) return;
    _progress.value = value;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _afterFrame() async {
    if (!mounted) return;
    // Both look-ups happen before the first await so no BuildContext is used
    // across an asynchronous gap.
    final SavedController saved = context.read<SavedController>();
    final ArticleRepository repository = context.read<ArticleRepository>();
    await saved.recordHistory(widget.article);
    try {
      final List<Article> related = await repository.relatedCoverage(widget.article);
      if (mounted) {
        setState(() {
          _related = related;
          _loadingRelated = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRelated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Article article = widget.article;
    final SourceRegistry registry = context.registry;
    final NewsSource? source = registry.byId(article.sourceId);
    final SettingsController settings = context.watch<SettingsController>();
    final double scale = settings.textScale;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              controller: _scroll,
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 58,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  leadingWidth: Tokens.gutter + 42,
                  leading: Padding(
                    padding: const EdgeInsetsDirectional.only(start: Tokens.gutter),
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
                    ShareAction(article: article, dense: true),
                    const SizedBox(width: 4),
                    GlassIconButton(
                      icon: Icons.translate_rounded,
                      tooltip: context.strings.translateAction,
                      onTap: () => showTranslationSheet(
                        context,
                        text: <String>[
                          article.title,
                          if ((article.excerpt ?? '').isNotEmpty) article.excerpt!,
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
                    scale: scale,
                    related: _related,
                    loadingRelated: _loadingRelated,
                  ),
                ),
              ],
            ),
            // Progress is drawn over the page rather than inside the app bar so
            // it stays a hairline instead of a coloured band.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 57,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ReadingProgressBar(progress: _progress, height: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.article,
    required this.source,
    required this.scale,
    required this.related,
    required this.loadingRelated,
  });

  final Article article;
  final NewsSource? source;
  final double scale;
  final List<Article> related;
  final bool loadingRelated;

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
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 2, Tokens.gutter, 18),
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
                  fontSize: 26 * scale,
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
                    fontSize: 16.8 * scale,
                    height: 1.92,
                    letterSpacing: 0.02,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _ExcerptNote(text: context.strings.excerptNotice),
              const SizedBox(height: 20),
              JellyButton(
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
              const SizedBox(height: 4),
              Center(
                child: JellySurface(
                  onTap: () => openUrlFeedback(context, article.link),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Text(
                      context.strings.readOriginal,
                      style: context.texts.labelMedium?.copyWith(
                        fontSize: 11.5,
                        color: context.colors.onSurfaceVariant,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            context.colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _QuietAction(
                      icon: Icons.link_rounded,
                      label: context.strings.copyLink,
                      onTap: () async {
                        await LinkLauncherShare.copyLink(context, article.link);
                        if (!context.mounted) return;
                        context.showSnack(context.strings.linkCopied);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuietAction(
                      icon: Icons.ios_share_rounded,
                      label: context.strings.share,
                      onTap: () =>
                          LinkLauncherShare.shareArticle(context, article),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (loadingRelated)
                const SkeletonBox(height: 64, radius: Tokens.radiusMd)
              else if (related.isNotEmpty) ...<Widget>[
                Kicker(context.strings.relatedCoverage),
                const SizedBox(height: 10),
                for (final Article other in related)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RelatedRow(
                      article: other,
                      source: registry.byId(other.sourceId),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (source != null) _SourceFooter(source: source!),
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
                        style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
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

class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: onTap,
      scale: 0.96,
      child: GlassPanel(
        radius: Tokens.radiusSm,
        blur: Tokens.blurSoft,
        elevation: 0.3,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
            const SizedBox(width: 7),
            Text(
              label,
              style: context.texts.labelMedium?.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
            if (source != null) ...<Widget>[
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
  const _SourceFooter({required this.source});

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
                icon: following
                    ? Icons.check_rounded
                    : Icons.add_rounded,
                onTap: () =>
                    context.read<SettingsController>().toggleFollow(source.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuietAction(
                  icon: Icons.public_rounded,
                  label: context.strings.openWebsite,
                  onTap: () => openUrlFeedback(context, source.website),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuietAction(
                  icon: Icons.info_outline_rounded,
                  label: context.strings.aboutPublication,
                  onTap: () => openSource(context, source),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Share helpers kept next to the reading screen.
class LinkLauncherShare {
  const LinkLauncherShare._();

  static Future<void> shareArticle(BuildContext context, Article article) async {
    final String sourceName =
        context.registry.nameOf(article.sourceId, bengali: context.isBengali);
    await LinkLauncher.share(
      '${article.title}\n\n$sourceName\n${article.link}',
      subject: article.title,
    );
  }

  static Future<void> copyLink(BuildContext context, String link) async {
    await LinkService.copyToClipboard(link);
  }
}
