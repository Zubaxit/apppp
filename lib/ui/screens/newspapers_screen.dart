import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../helpers/app_nav.dart';
import '../widgets/common.dart';
import '../widgets/feed_widgets.dart';
import 'epaper_directory_screen.dart';
import 'search_screen.dart';

/// Searchable, filterable directory of every publication in the registry.
class NewspapersScreen extends StatefulWidget {
  const NewspapersScreen({
    super.key,
    this.standalone = false,
    this.initialCategory,
    this.initialDivision,
  });

  final bool standalone;
  final SourceCategory? initialCategory;
  final String? initialDivision;

  @override
  State<NewspapersScreen> createState() => _NewspapersScreenState();
}

class _NewspapersScreenState extends State<NewspapersScreen> {
  final TextEditingController _searchController = TextEditingController();
  SourceCategory? _category;
  SourceLanguage? _language;
  String? _division;
  String _query = '';
  bool _onlyWithFeeds = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _division = widget.initialDivision;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _category != null || _language != null || _division != null || _onlyWithFeeds;

  List<NewsSource> _results(SourceRegistry registry) {
    final List<NewsSource> base = _query.trim().isEmpty
        ? registry.filter(
            category: _category,
            language: _language,
            division: _division,
            onlyWithFeeds: _onlyWithFeeds,
          )
        : registry
            .search(_query)
            .where((NewsSource s) {
              if (_category != null && !s.categories.contains(_category)) return false;
              if (_language != null && s.language != _language) return false;
              if (_division != null && s.division != _division) return false;
              if (_onlyWithFeeds && !s.hasFeed) return false;
              return true;
            })
            .toList();
    base.sort((NewsSource a, NewsSource b) => a
        .localizedName(bengali: context.isBengali)
        .compareTo(b.localizedName(bengali: context.isBengali)));
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final SourceRegistry registry = context.registry;
    final FeedController feed = context.watch<FeedController>();
    final SettingsController settings = context.watch<SettingsController>();
    final bool bengali = context.isBengali;
    final List<NewsSource> results = _results(registry);
    final List<String> divisions = registry.divisionsWithSources;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Text(context.strings.directoryTitle),
        actions: <Widget>[
          IconButton(
            tooltip: context.strings.epaperSectionTitle,
            onPressed: () => Navigator.of(context).push<void>(
              editorialRoute<void>(const EpaperDirectoryScreen(), name: 'epapers'),
            ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: context.strings.searchTitle,
            onPressed: () => Navigator.of(context).push<void>(
              editorialRoute<void>(const SearchScreen(), name: 'search'),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (String value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: context.texts.bodyMedium,
              decoration: InputDecoration(
                hintText: context.strings.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
          FilterChipRow<SourceCategory?>(
            options: <SourceCategory?>[null, ...SourceCategory.values],
            selected: _category,
            labelOf: (SourceCategory? value) => value == null
                ? context.strings.allCategories
                : Labels.category(value, bengali: bengali),
            onSelected: (SourceCategory? value) => setState(() => _category = value),
          ),
          const SizedBox(height: 6),
          FilterChipRow<SourceLanguage?>(
            options: <SourceLanguage?>[null, SourceLanguage.bn, SourceLanguage.en],
            selected: _language,
            labelOf: (SourceLanguage? value) => value == null
                ? context.strings.allLanguages
                : Labels.language(value, bengali: bengali),
            onSelected: (SourceLanguage? value) => setState(() => _language = value),
          ),
          if (divisions.isNotEmpty && _category == SourceCategory.regional) ...<Widget>[
            const SizedBox(height: 6),
            FilterChipRow<String?>(
              options: <String?>[null, ...divisions],
              selected: _division,
              labelOf: (String? value) => value ?? context.strings.allDivisions,
              onSelected: (String? value) => setState(() => _division = value),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 2),
            child: Row(
              children: <Widget>[
                Text(
                  '${results.length} ${context.strings.publicationsCount}',
                  style: context.texts.labelMedium,
                ),
                const Spacer(),
                FilterChip(
                  selected: _onlyWithFeeds,
                  label: Text(
                    bengali ? 'ফিড আছে' : 'Has feed',
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: _onlyWithFeeds ? context.colors.onPrimary : null,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (bool value) => setState(() => _onlyWithFeeds = value),
                ),
                if (_hasFilters)
                  TextButton(
                    onPressed: () => setState(() {
                      _category = null;
                      _language = null;
                      _division = null;
                      _onlyWithFeeds = false;
                    }),
                    child: Text(context.strings.clear, style: context.texts.labelSmall),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? ListView(
                    children: <Widget>[
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: context.strings.noResultsTitle,
                        body: context.strings.noResultsBody,
                        actionLabel: _hasFilters ? context.strings.clear : null,
                        onAction: _hasFilters
                            ? () => setState(() {
                                  _category = null;
                                  _language = null;
                                  _division = null;
                                  _onlyWithFeeds = false;
                                })
                            : null,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 30),
                    itemCount: results.length,
                    separatorBuilder: (BuildContext context, int index) => Divider(
                      height: 0.6,
                      thickness: 0.6,
                      indent: 80,
                      endIndent: 20,
                      color: context.colors.outlineVariant,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final NewsSource source = results[index];
                      return PublicationTile(
                        source: source,
                        health: feed.healthFor(source.id),
                        following: settings.isFollowing(source.id),
                        onTap: () => openSource(context, source),
                        onToggleFollow: () async {
                          await context.read<SettingsController>().toggleFollow(source.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
