import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../helpers/app_nav.dart';
import '../widgets/article_card.dart';
import '../widgets/common.dart';
import '../widgets/feed_widgets.dart';

/// Unified search over the publication registry and the cached headlines.
/// Bengali and English queries both work; the registry matcher also maps
/// Bengali names onto their Latin spellings.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<NewsSource> _sources = const <NewsSource>[];
  List<Article> _articles = const <Article>[];
  bool _busy = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () => _run(value));
  }

  Future<void> _run(String raw) async {
    final String query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _sources = const <NewsSource>[];
        _articles = const <Article>[];
        _searched = false;
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    final SourceRegistry registry = context.registry;
    final List<NewsSource> sources = registry.search(query, limit: 10);
    List<Article> articles = const <Article>[];
    try {
      articles = await context.read<ArticleRepository>().searchArticles(query, limit: 30);
    } catch (_) {
      articles = const <Article>[];
    }
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _articles = articles;
      _busy = false;
      _searched = true;
    });
  }

  Future<void> _submit(String value) async {
    if (value.trim().isEmpty) return;
    await context.read<SettingsController>().rememberSearch(value);
    await _run(value);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final SourceRegistry registry = context.registry;
    final FeedController feed = context.watch<FeedController>();
    final bool bengali = context.isBengali;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          style: context.texts.bodyLarge,
          decoration: InputDecoration(
            hintText: context.strings.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: _submit,
        ),
      ),
      body: _query.trim().isEmpty
          ? ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 30),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(context.strings.searchBothHint, style: context.texts.bodySmall),
                ),
                if (settings.prefs.searchHistory.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  SectionHeader(title: context.strings.recentSearches),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: settings.prefs.searchHistory.map((String term) {
                        return ActionChip(
                          avatar: const Icon(Icons.history_rounded, size: 15),
                          label: Text(term),
                          onPressed: () {
                            _controller.text = term;
                            _onChanged(term);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SectionHeader(title: context.strings.browseDirectory),
                PrimaryActionCard(
                  icon: Icons.newspaper_rounded,
                  title: context.strings.directoryTitle,
                  subtitle: bengali
                      ? '${registry.sources.length}টি পত্রিকা ও পোর্টাল'
                      : '${registry.sources.length} newspapers and portals',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            )
          : _busy
              ? const ArticleSkeleton(count: 4)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 30),
                  children: <Widget>[
                    if (_sources.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        title: context.strings.searchInPapers,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      ),
                      ..._sources.map((NewsSource source) => PublicationTile(
                            source: source,
                            health: feed.healthFor(source.id),
                            following: settings.isFollowing(source.id),
                            onTap: () => openSource(context, source),
                            onToggleFollow: () =>
                                context.read<SettingsController>().toggleFollow(source.id),
                          )),
                    ],
                    if (_articles.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      SectionHeader(
                        title: context.strings.searchInArticles,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      ),
                      ..._articles.map((Article article) => Column(
                            children: <Widget>[
                              ArticleCard(
                                article: article,
                                source: registry.byId(article.sourceId),
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
                    ],
                    if (_searched && _sources.isEmpty && _articles.isEmpty)
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: context.strings.noResultsTitle,
                        body: context.strings.noResultsBody,
                      ),
                  ],
                ),
    );
  }
}
