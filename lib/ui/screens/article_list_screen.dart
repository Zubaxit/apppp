import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/feed_query.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
import '../../theme/materials.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial_story.dart';

/// A filtered article list used by sections, followed publications and
/// "see all" actions. It talks to the repository directly so it never disturbs
/// the home feed's own filter state.
///
/// It keeps the river's card so a story looks the same wherever it is met; only
/// the header changes to say which slice of the feed this is.
class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.topics = const <ArticleTopic>{},
    this.sourceIds = const <String>{},
    this.languages = const <SourceLanguage>{},
  });

  final String title;
  final String? subtitle;
  final Set<ArticleTopic> topics;
  final Set<String> sourceIds;
  final Set<SourceLanguage> languages;

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  List<Article> _articles = const <Article>[];
  bool _loading = true;
  int _limit = 60;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Article> articles =
          await context.read<ArticleRepository>().loadFeed(
                FeedQuery(
                  topics: widget.topics,
                  sourceIds: widget.sourceIds,
                  languages: widget.languages,
                  limit: _limit,
                ),
              );
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.strings.errorBody;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      await context.read<ArticleRepository>().refresh(
            force: true,
            onlySourceIds: widget.sourceIds.isEmpty ? null : widget.sourceIds,
          );
    } catch (_) {
      // Per-source failures are reflected in the source health screen.
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final SourceRegistry registry = context.registry;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Tokens.gutter, 8, Tokens.gutter, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.strings.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.titleLarge?.copyWith(
                              fontFamily: Tokens.serif,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.labelSmall
                                  ?.copyWith(fontSize: 10.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SoftRule(inset: Tokens.gutter, thickness: 0.8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: context.colors.primary,
                  backgroundColor: context.colors.surface,
                  child: _loading
                      ? const ArticleSkeleton(count: 6)
                      : _articles.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.only(bottom: 120),
                              children: <Widget>[
                                if (_error != null)
                                  EmptyState(
                                    icon: Icons.error_outline_rounded,
                                    title: context.strings.loadError,
                                    body: _error!,
                                    actionLabel: context.strings.retry,
                                    onAction: _load,
                                  )
                                else
                                  EmptyState(
                                    icon: Icons.article_outlined,
                                    title: context.strings.emptyFeedTitle,
                                    body: context.strings.categoryEmpty,
                                    actionLabel: context.strings.retry,
                                    onAction: _refresh,
                                  ),
                              ],
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 120),
                              itemCount: _articles.length + 1,
                              itemBuilder: (BuildContext context, int index) {
                                if (index == _articles.length) {
                                  if (_articles.length < _limit) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        Tokens.gutter,
                                        18,
                                        Tokens.gutter,
                                        24,
                                      ),
                                      child: Center(
                                        child: Text(
                                          context.strings.feedEnd,
                                          style: context.texts.labelSmall
                                              ?.copyWith(
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      Tokens.gutter,
                                      14,
                                      Tokens.gutter,
                                      24,
                                    ),
                                    child: Center(
                                      child: GlassChip(
                                        label: context.strings.viewAll,
                                        icon: Icons.expand_more_rounded,
                                        onTap: () {
                                          _limit += 60;
                                          _load();
                                        },
                                      ),
                                    ),
                                  );
                                }
                                final Article article = _articles[index];
                                return NewsCard(
                                  article: article,
                                  source: registry.byId(article.sourceId),
                                  onTap: () => openArticle(context, article),
                                );
                              },
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
