import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/services/article_repository.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
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
      articles = await context
          .read<ArticleRepository>()
          .searchArticles(query, limit: 30);
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
            body: context.strings.noResultsBody,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 130),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
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
            child: Eyebrow(context.strings.searchInArticles),
          ),
          for (int i = 0; i < _articles.length; i++)
            RiseIn(
              index: i,
              child: NewsCard(
                article: _articles[i],
                source: registry.byId(_articles[i].sourceId),
                onTap: () => openArticle(context, _articles[i]),
              ),
            ),
        ],
      ],
    );
  }
}
