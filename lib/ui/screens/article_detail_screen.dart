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
import '../helpers/app_nav.dart';
import '../services/link_launcher.dart';
import '../widgets/common.dart';

/// Reading surface for an aggregated story.
///
/// Only the headline, the excerpt the publisher put in its feed and a link are
/// shown. The full article is always read on the publisher's site.
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  List<Article> _related = const <Article>[];
  bool _loadingRelated = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFrame());
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
    final bool bengali = context.isBengali;
    final bool isSaved = context.watch<SavedController>().isSaved(article.id);
    final SettingsController settings = context.watch<SettingsController>();
    final double scale = settings.textScale;
    final String sourceName =
        source?.localizedName(bengali: bengali) ?? article.sourceId;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            actions: <Widget>[
              IconButton(
                tooltip: isSaved ? context.strings.removeSaved : context.strings.save,
                onPressed: () async {
                  final bool nowSaved =
                      await context.read<SavedController>().toggle(article);
                  if (!context.mounted) return;
                  context.showSnack(
                    nowSaved ? context.strings.savedLabel : context.strings.removeSaved,
                  );
                },
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                ),
              ),
              IconButton(
                tooltip: context.strings.share,
                onPressed: () => LinkLauncherShare.shareArticle(context, article),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (article.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: RemoteImage(url: article.imageUrl!),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InkWell(
                        onTap: source == null ? null : () => openSource(context, source),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: <Widget>[
                              if (source != null) ...<Widget>[
                                SourceAvatar(source: source, size: 30),
                                const SizedBox(width: 9),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      sourceName,
                                      style: context.texts.labelLarge?.copyWith(
                                        color: context.colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: <Widget>[
                                        if (article.breaking) ...<Widget>[
                                          Text(
                                            bengali ? 'ব্রেকিং · ' : 'BREAKING · ',
                                            style: context.texts.labelSmall?.copyWith(
                                              color: context.colors.error,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
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
                                            style: context.texts.labelSmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        article.title,
                        style: context.texts.displaySmall?.copyWith(
                          fontSize: 25 * scale,
                          height: 1.34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (article.author != null)
                        Text(
                          article.author!,
                          style: context.texts.labelSmall?.copyWith(fontSize: 11),
                        ),
                      const SizedBox(height: 14),
                      Container(height: 0.8, color: context.colors.outlineVariant),
                      const SizedBox(height: 16),
                      if ((article.excerpt ?? '').isNotEmpty) ...<Widget>[
                        Text(
                          article.excerpt!,
                          style: context.texts.bodyLarge?.copyWith(
                            fontSize: 16.5 * scale,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                context.strings.excerptNotice,
                                style: context.texts.labelSmall?.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => openUrlFeedback(context, article.link, inApp: true),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(context.strings.readOriginal),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await LinkLauncherShare.copyLink(context, article.link);
                                if (!context.mounted) return;
                                context.showSnack(context.strings.linkCopied);
                              },
                              icon: const Icon(Icons.link_rounded, size: 17),
                              label: Text(context.strings.copyLink),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: context.colors.outlineVariant),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => LinkLauncherShare.shareArticle(context, article),
                              icon: const Icon(Icons.share_outlined, size: 17),
                              label: Text(context.strings.share),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: context.colors.outlineVariant),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      if (_loadingRelated)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SkeletonBox(height: 54, radius: 12),
                        )
                      else if (_related.isNotEmpty) ...<Widget>[
                        SectionHeader(
                          title: context.strings.relatedCoverage,
                          padding: const EdgeInsets.only(bottom: 8),
                        ),
                        ..._related.map((Article other) {
                          final NewsSource? otherSource = registry.byId(other.sourceId);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: context.colors.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: otherSource == null
                                    ? null
                                    : SourceAvatar(source: otherSource, size: 30),
                                title: Text(
                                  other.title,
                                  style: context.texts.titleSmall?.copyWith(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${otherSource?.localizedName(bengali: bengali) ?? other.sourceId} · '
                                  '${BengaliText.relative(other.publishedAt, bengali: bengali) ?? ''}',
                                  style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                onTap: () => openArticle(context, other),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                      if (source != null) _SourceFooter(source: source),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({required this.source});

  final NewsSource source;

  @override
  Widget build(BuildContext context) {
    final bool following = context.watch<SettingsController>().isFollowing(source.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outlineVariant),
      ),
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
                      style: context.texts.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      publicationMeta(source, bengali: context.isBengali),
                      style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.read<SettingsController>().toggleFollow(source.id),
                child: Text(
                  following ? context.strings.followingLabel : context.strings.follow,
                  style: context.texts.labelMedium?.copyWith(
                    color: following ? context.colors.onSurfaceVariant : context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openUrlFeedback(context, source.website),
                  icon: const Icon(Icons.public_rounded, size: 16),
                  label: Text(
                    context.strings.openWebsite,
                    style: context.texts.labelMedium,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.colors.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openSource(context, source),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: Text(
                    context.strings.aboutPublication,
                    style: context.texts.labelMedium,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.colors.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
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
