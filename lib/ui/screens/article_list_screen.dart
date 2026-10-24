import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/feed_query.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
import '../helpers/app_nav.dart';
import '../widgets/article_card.dart';
import '../widgets/common.dart';

/// A filtered article list used by sections, followed publications and
/// "see all" actions. It talks to the repository directly so it never disturbs
/// the home feed's own filter state.
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
      final List<Article> articles = await context.read<ArticleRepository>().loadFeed(
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.title),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: context.texts.labelSmall),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const ArticleSkeleton(count: 6)
            : _articles.isEmpty
                ? ListView(
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
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 30, top: 4),
                    itemCount: _articles.length + 1,
                    separatorBuilder: (BuildContext context, int index) => Divider(
                      height: 0.6,
                      thickness: 0.6,
                      indent: 20,
                      endIndent: 20,
                      color: context.colors.outlineVariant,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == _articles.length) {
                        if (_articles.length < _limit) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                context.strings.feedEnd,
                                style: context.texts.labelSmall,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(18),
                          child: OutlinedButton(
                            onPressed: () {
                              _limit += 60;
                              _load();
                            },
                            child: Text(context.strings.viewAll),
                          ),
                        );
                      }
                      final Article article = _articles[index];
                      return ArticleCard(
                        article: article,
                        source: registry.byId(article.sourceId),
                        onTap: () => openArticle(context, article),
                      );
                    },
                  ),
      ),
    );
  }
}
