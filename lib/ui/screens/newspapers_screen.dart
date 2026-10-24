import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/editorial.dart';

/// The reading room: a short, deliberate list of publications.
///
/// The curated set leads. Everything else in the registry stays reachable
/// behind "all publications" so nothing is hidden, only prioritised.
class NewspapersScreen extends StatefulWidget {
  const NewspapersScreen({super.key, this.standalone = false, this.initialDivision});

  final bool standalone;

  /// Pre-selects a division when arriving from the regional browse chips.
  final String? initialDivision;

  @override
  State<NewspapersScreen> createState() => _NewspapersScreenState();
}

class _NewspapersScreenState extends State<NewspapersScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _showAll = false;
  String? _division;
  String? _district;

  @override
  void initState() {
    super.initState();
    _division = widget.initialDivision;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _searching => _query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final SourceRegistry registry = context.registry;
    final SettingsController settings = context.watch<SettingsController>();
    final FeedController feed = context.watch<FeedController>();

    final List<NewsSource> matches = _searching ? registry.search(_query) : const <NewsSource>[];
    final List<NewsSource> curatedFeeds = registry.curatedWithFeeds;
    final List<NewsSource> curatedWeb = registry.curatedWebOnly;
    final List<NewsSource> rest = registry.sources
        .where((NewsSource s) => !s.curated)
        .toList()
      ..sort((NewsSource a, NewsSource b) => a.name.compareTo(b.name));

    final List<String> divisions = <String>{
      ...registry.divisionsWithSources,
      // A division passed in from another screen stays visible even if the
      // registry currently has no publication for it.
      if (_division != null) _division!,
    }.toList()
      ..sort();
    // The cascade has to sit inside the conditional: `a ? b : c..sort()` sorts
    // the whole conditional, and the "no division" branch is a const list.
    final List<NewsSource> regional = _division == null
        ? const <NewsSource>[]
        : (registry.sources
              .where((NewsSource s) =>
                  s.division == _division && (_district == null || s.district == _district))
              .toList()
            ..sort((NewsSource a, NewsSource b) => a.name.compareTo(b.name)));
    final List<String> districts =
        _division == null ? const <String>[] : registry.districtsIn(_division!);

    final Widget body = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        if (!widget.standalone)
          const SliverToBoxAdapter(child: SizedBox(height: 10))
        else
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            title: Text(context.strings.directoryTitle),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 6, Tokens.gutter, 8),
            child: TextField(
              controller: _search,
              onChanged: (String value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: context.texts.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.strings.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searching
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (divisions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.gutter, 4, Tokens.gutter, 2),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(context.strings.allDivisions),
                    selected: _division == null,
                    onSelected: (bool _) => setState(() {
                      _division = null;
                      _district = null;
                    }),
                  ),
                  for (final String division in divisions)
                    ChoiceChip(
                      label: Text(Labels.division(division, bengali: context.isBengali)),
                      selected: _division == division,
                      onSelected: (bool selected) => setState(() {
                        _division = selected ? division : null;
                        _district = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
        if (_division != null && districts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.gutter, 2, Tokens.gutter, 2),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(context.strings.all),
                    selected: _district == null,
                    onSelected: (bool _) => setState(() => _district = null),
                  ),
                  for (final String district in districts)
                    ChoiceChip(
                      label: Text(district),
                      selected: _district == district,
                      onSelected: (bool selected) =>
                          setState(() => _district = selected ? district : null),
                    ),
                ],
              ),
            ),
          ),
        if (_searching)
          _searchResults(matches, settings, feed)
        else if (_division != null) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 6),
              child: Kicker(
                '${context.strings.regionalSources} · '
                '${Labels.division(_division!, bengali: context.isBengali)}',
              ),
            ),
          ),
          if (regional.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 0),
                child: Text(context.strings.regionalEmpty, style: context.texts.bodySmall),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _SourceRow(
                  source: regional[index],
                  following: settings.isFollowing(regional[index].id),
                  health: feed.healthFor(regional[index].id),
                  webOnly: !regional[index].hasFeed,
                  last: index == regional.length - 1,
                  onTap: () => openSource(context, regional[index]),
                  onToggleFollow: () => settings.toggleFollow(regional[index].id),
                ),
                childCount: regional.length,
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ]
        else ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.gutter, 14, Tokens.gutter, 0),
              child: Kicker(context.strings.inYourFeed),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _SourceRow(
                source: curatedFeeds[index],
                following: settings.isFollowing(curatedFeeds[index].id),
                health: feed.healthFor(curatedFeeds[index].id),
                last: index == curatedFeeds.length - 1,
                onTap: () => openSource(context, curatedFeeds[index]),
                onToggleFollow: () => settings.toggleFollow(curatedFeeds[index].id),
              ),
              childCount: curatedFeeds.length,
            ),
          ),
          if (curatedWeb.isNotEmpty) ...<Widget>[
            const SizedBox(height: 26),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 0),
                child: Kicker(context.strings.readOnWeb),
              ),
            ),
            const SizedBox(height: 6),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 6),
                child: Text(
                  context.strings.noHeadlinesYet,
                  style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _SourceRow(
                  source: curatedWeb[index],
                  following: settings.isFollowing(curatedWeb[index].id),
                  health: null,
                  webOnly: true,
                  last: index == curatedWeb.length - 1,
                  onTap: () => openSource(context, curatedWeb[index]),
                  onToggleFollow: () => settings.toggleFollow(curatedWeb[index].id),
                ),
                childCount: curatedWeb.length,
              ),
            ),
          ],
          const SizedBox(height: 30),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
              child: Pressable(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    border: Border.all(
                      color: context.isDark ? Tokens.nightHairline : Tokens.hairline,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.public_rounded, size: 16, color: context.colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${context.strings.allPublications} · ${registry.sources.length}',
                          style: context.texts.titleSmall?.copyWith(fontSize: 13),
                        ),
                      ),
                      Icon(
                        _showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showAll) ...<Widget>[
            const SizedBox(height: 8),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _SourceRow(
                  source: rest[index],
                  following: settings.isFollowing(rest[index].id),
                  health: feed.healthFor(rest[index].id),
                  webOnly: !rest[index].hasFeed,
                  last: index == rest.length - 1,
                  onTap: () => openSource(context, rest[index]),
                  onToggleFollow: () => settings.toggleFollow(rest[index].id),
                ),
                childCount: rest.length,
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ],
    );

    if (!widget.standalone) return body;
    return Scaffold(body: body);
  }

  Widget _searchResults(
    List<NewsSource> matches,
    SettingsController settings,
    FeedController feed,
  ) {
    if (matches.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.gutter, 30, Tokens.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.strings.noResultsTitle, style: context.texts.headlineSmall),
              const SizedBox(height: 6),
              Text(context.strings.noResultsBody, style: context.texts.bodySmall),
            ],
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => _SourceRow(
          source: matches[index],
          following: settings.isFollowing(matches[index].id),
          health: feed.healthFor(matches[index].id),
          webOnly: !matches[index].hasFeed,
          last: index == matches.length - 1,
          onTap: () => openSource(context, matches[index]),
          onToggleFollow: () => settings.toggleFollow(matches[index].id),
        ),
        childCount: matches.length,
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.following,
    required this.health,
    required this.onTap,
    required this.onToggleFollow,
    this.last = false,
    this.webOnly = false,
  });

  final NewsSource source;
  final bool following;
  final dynamic health;
  final VoidCallback onTap;
  final VoidCallback onToggleFollow;
  final bool last;
  final bool webOnly;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String? secondary = source.secondaryName(bengali: bengali);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: <Widget>[
                  SourceMark(source: source, size: 38),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          source.localizedName(bengali: bengali),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleSmall?.copyWith(
                            fontFamily: Tokens.serif,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          webOnly
                              ? context.strings.openMainWebsite
                              : (secondary ??
                                  Labels.language(source.language, bengali: bengali)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: onToggleFollow,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        following
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 19,
                        color: following
                            ? context.colors.primary
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!last) const Hairline(indent: 51),
          ],
        ),
      ),
    );
  }
}
