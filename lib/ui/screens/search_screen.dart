import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../core/utils/story_matcher.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
import '../../services/archive_search.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial.dart';
import '../widgets/editorial_story.dart';
import '../widgets/feed_widgets.dart';

/// Unified search over the publication registry and the cached headlines.
/// Bengali and English queries both work; the registry matcher also maps
/// Bengali names onto their Latin spellings.
///
/// The field sits in a glass capsule at the top and stays the only bright
/// element on the screen: results are paper, chrome is glass.
enum SearchMode { app, archive }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.archiveService});

  /// Tests and future official publisher providers can inject the same service.
  final ArchiveSearchService? archiveService;

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
  SearchMode _mode = SearchMode.app;
  ArchiveSearchService? _archive;
  List<String> _archiveWarnings = const <String>[];
  Map<String, List<Article>> _archiveRelated =
      const <String, List<Article>>{};
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _archive ??= widget.archiveService ??
        ArchiveSearchService(
          providers: <ArchiveSearchProvider>[
            CachedArticleArchiveProvider(context.read<ArticleRepository>()),
          ],
        );
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
    final bool bengali = context.isBengali;
    final int generation = ++_requestGeneration;
    if (query.isEmpty) {
      setState(() {
        _sources = const <NewsSource>[];
        _articles = const <Article>[];
        _archiveWarnings = const <String>[];
        _archiveRelated = const <String, List<Article>>{};
        _searched = false;
        _busy = false;
      });
      return;
    }
    setState(() => _busy = true);
    final SourceRegistry registry = context.registry;
    List<NewsSource> sources = const <NewsSource>[];
    List<Article> articles = const <Article>[];
    List<String> warnings = const <String>[];
    try {
      if (_mode == SearchMode.archive) {
        final ArchiveSearchResponse response = await _archive!.search(
          ArchiveSearchQuery(text: query),
        );
        articles = response.articles;
        warnings = response.warnings;
      } else {
        sources = registry.search(query, limit: 10);
        articles = await context
            .read<ArticleRepository>()
            .searchArticles(query, limit: 30);
      }
    } catch (_) {
      warnings = <String>[
        bengali
            ? 'উপলভ্য আর্কাইভে এখন খোঁজা যায়নি।'
            : 'The available archive could not be searched.',
      ];
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _sources = sources;
      _articles = articles;
      _archiveWarnings = warnings;
      _archiveRelated = _mode == SearchMode.archive
          ? StoryMatcher.index(articles)
          : const <String, List<Article>>{};
      _busy = false;
      _searched = true;
    });
  }

  void _setMode(SearchMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _sources = const <NewsSource>[];
      _articles = const <Article>[];
      _searched = false;
    });
    if (_query.trim().isNotEmpty) unawaited(_run(_query));
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
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 8),
                child: Row(
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.strings.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _field(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.gutter,
                  2,
                  Tokens.gutter,
                  8,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: GlassChip(
                        label: bengali ? 'অ্যাপের খবর' : 'App news',
                        icon: Icons.dynamic_feed_outlined,
                        selected: _mode == SearchMode.app,
                        onTap: () => _setMode(SearchMode.app),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassChip(
                        label: bengali
                            ? 'পুরোনো খবর খুঁজুন'
                            : 'Archive search',
                        icon: Icons.manage_search_rounded,
                        selected: _mode == SearchMode.archive,
                        onTap: () => _setMode(SearchMode.archive),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _query.trim().isEmpty
                    ? _idle(context, settings, registry, bengali)
                    : _result(context, registry, feed),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context) {
    return GlassPanel(
      radius: Tokens.radiusPill,
      // The field scrolls with the results; a blur behind it would re-run on
      // every scroll frame to reveal nothing.
      blur: 0,
      elevation: 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: 17,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              cursorColor: context.colors.primary,
              style: context.texts.bodyLarge?.copyWith(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: context.strings.searchHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                hintStyle: context.texts.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              onChanged: _onChanged,
              onSubmitted: _submit,
            ),
          ),
          if (_query.isNotEmpty)
            JellySurface(
              scale: 0.86,
              onTap: () {
                _controller.clear();
                _onChanged('');
                _focus.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _idle(
    BuildContext context,
    SettingsController settings,
    SourceRegistry registry,
    bool bengali,
  ) {
    final List<String> history = settings.prefs.searchHistory;
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 130),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
          child: Text(
            context.strings.searchBothHint,
            style: context.texts.bodySmall?.copyWith(height: 1.6, fontSize: 12),
          ),
        ),
        if (history.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 26, Tokens.gutter, 10),
            child: Eyebrow(context.strings.recentSearches),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: history.map((String term) {
                return GlassChip(
                  label: term,
                  icon: Icons.history_rounded,
                  dense: true,
                  onTap: () {
                    _controller.text = term;
                    _onChanged(term);
                    _submit(term);
                  },
                );
              }).toList(),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.gutter, 30, Tokens.gutter, 10),
          child: Eyebrow(context.strings.browseDirectory),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
          child: PrimaryActionCard(
            icon: Icons.newspaper_rounded,
            title: context.strings.directoryTitle,
            body: bengali
                ? '${BengaliText.toBengaliDigits(registry.sources.length)}টি পত্রিকা ও পোর্টাল'
                : '${registry.sources.length} newspapers and portals',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _result(
    BuildContext context,
    SourceRegistry registry,
    FeedController feed,
  ) {
    if (_busy) return const ArticleSkeleton(count: 4);
    if (!_searched) return const SizedBox.shrink();
    if (_sources.isEmpty && _articles.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: <Widget>[
          EmptyState(
            icon: Icons.search_off_rounded,
            title: context.strings.noResultsTitle,
            body: _mode == SearchMode.archive
                ? (context.isBengali
                    ? 'উপলভ্য প্রকাশক-ফিড ক্যাশে খবরটি পাওয়া যায়নি। শব্দ বা বানান বদলে চেষ্টা করুন। সব প্রকাশকের পূর্ণ আর্কাইভ উন্মুক্ত নয়।'
                    : 'No match was exposed by the available retained publisher feeds. Refine the query; not every publisher exposes a full archive.')
                : context.strings.noResultsBody,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 130),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (_mode == SearchMode.archive) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.gutter,
              8,
              Tokens.gutter,
              10,
            ),
            child: Text(
              <String>[
                context.isBengali
                    ? 'পুরোনো খবর · লাইভ ফিড থেকে আলাদা'
                    : 'Archive results · separate from the live feed',
                ..._archiveWarnings,
              ].join('\n'),
              style: context.texts.labelSmall?.copyWith(
                height: 1.5,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (_sources.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 6),
            child: Eyebrow(context.strings.searchInPapers),
          ),
          ..._sources.map(
            (NewsSource source) => PublicationTile(
              source: source,
              health: feed.healthFor(source.id),
              following: context.read<SettingsController>().isFollowing(source.id),
              onTap: () => openSource(context, source),
              onFollow: () =>
                  context.read<SettingsController>().toggleFollow(source.id),
            ),
          ),
        ],
        if (_articles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 8),
            child: Eyebrow(_mode == SearchMode.archive
                ? (context.isBengali ? 'আর্কাইভ ফলাফল' : 'Archive results')
                : context.strings.searchInArticles),
          ),
          for (int i = 0; i < _articles.length; i++)
            RiseIn(
              index: i,
              child: NewsCard(
                article: _articles[i],
                source: registry.byId(_articles[i].sourceId),
                related: _mode == SearchMode.archive
                    ? (_archiveRelated[_articles[i].id] ?? const <Article>[])
                    : null,
                onTap: () => openArticle(
                  context,
                  _articles[i],
                  related: _mode == SearchMode.archive
                      ? (_archiveRelated[_articles[i].id] ?? const <Article>[])
                      : null,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
