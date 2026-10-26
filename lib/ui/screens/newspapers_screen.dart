import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../state/feed_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/common.dart';
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
  SourceLanguage? _language;

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

    bool kept(NewsSource source) => _language == null || source.language == _language;
    final List<NewsSource> matches = _searching ? registry.search(_query) : const <NewsSource>[];
    final List<NewsSource> curatedFeeds =
        registry.curatedWithFeeds.where(kept).toList();
    final List<NewsSource> curatedWeb = registry.curatedWebOnly.where(kept).toList();
    final List<NewsSource> rest = (registry.sources
          .where((NewsSource s) => !s.curated && kept(s))
          .toList())
      ..sort((NewsSource a, NewsSource b) => a.name.compareTo(b.name));

    // With nothing curated the directory opens fully instead of showing an
    // empty front page with everything hidden behind a toggle.
    final bool showAll = _showAll || (curatedFeeds.isEmpty && curatedWeb.isEmpty);

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
                  s.division == _division &&
                  (_district == null || s.district == _district) &&
                  kept(s))
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
            toolbarHeight: 62,
            backgroundColor: context.theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: Tokens.gutter,
            title: Text(
              context.strings.directoryTitle,
              style: context.texts.titleLarge?.copyWith(
                fontFamily: Tokens.serif,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 6, Tokens.gutter, 8),
            child: GlassPanel(
              radius: Tokens.radiusMd,
              blur: 0,
              elevation: 0.4,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
        ),
        if (divisions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.gutter, 4, Tokens.gutter, 2),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  GlassChip(
                    label: context.strings.allDivisions,
                    selected: _division == null,
                    dense: true,
                    onTap: () => setState(() {
                      _division = null;
                      _district = null;
                    }),
                  ),
                  for (final String division in divisions)
                    GlassChip(
                      label: Labels.division(division, bengali: context.isBengali),
                      selected: _division == division,
                      dense: true,
                      onTap: () => setState(() {
                        _division = _division == division ? null : division;
                        _district = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.gutter, 2, Tokens.gutter, 2),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                GlassChip(
                  label: context.strings.allLanguages,
                  selected: _language == null,
                  dense: true,
                  onTap: () => setState(() => _language = null),
                ),
                for (final SourceLanguage language in SourceLanguage.values)
                  GlassChip(
                    label: Labels.language(language, bengali: context.isBengali),
                    selected: _language == language,
                    dense: true,
                    onTap: () => setState(
                      () => _language = _language == language ? null : language,
                    ),
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
                  GlassChip(
                    label: context.strings.all,
                    selected: _district == null,
                    dense: true,
                    onTap: () => setState(() => _district = null),
                  ),
                  for (final String district in districts)
                    GlassChip(
                      label: district,
                      selected: _district == district,
                      dense: true,
                      onTap: () => setState(
                        () => _district = _district == district ? null : district,
                      ),
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
            const SliverPadding(padding: EdgeInsets.only(top: 26)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 0),
                child: Kicker(context.strings.readOnWeb),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 6)),
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
          const SliverPadding(padding: EdgeInsets.only(top: 30)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
              child: Pressable(
                onTap: () => setState(() => _showAll = !_showAll),
                child: GlassPanel(
                  radius: Tokens.radiusMd,
                  blur: 0,
                  elevation: 0.4,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
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
                        showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showAll) ...<Widget>[
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
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

    if (!widget.standalone) return AuroraBackdrop(child: body);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(child: body),
    );
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
  final SourceHealth? health;
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
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: <Widget>[
                  SourceAvatar(source: source, size: 40),
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
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                webOnly
                                    ? context.strings.openMainWebsite
                                    : (secondary ??
                                        Labels.language(
                                          source.language,
                                          bengali: bengali,
                                        )),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    context.texts.labelSmall?.copyWith(fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 7),
                            HealthBadge(health: health, hasFeed: source.hasFeed),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: following
                        ? context.strings.followingLabel
                        : context.strings.follow,
                    child: JellySurface(
                      onTap: onToggleFollow,
                      scale: 0.86,
                      child: AnimatedContainer(
                        duration: Motion.of(context).standard,
                        curve: Tokens.easeStandard,
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: following
                              ? context.colors.primary.withValues(alpha: 0.13)
                              : Colors.transparent,
                          border: Border.all(
                            color: following
                                ? context.colors.primary.withValues(alpha: 0.4)
                                : (context.isDark
                                    ? Tokens.nightHairline
                                    : Tokens.hairline),
                            width: 0.9,
                          ),
                        ),
                        // Follow uses the same pair of icons as the publication
                        // page; a bookmark would read as "save this article".
                        child: Icon(
                          following
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          size: 19,
                          color: following
                              ? context.colors.primary
                              : context.colors.onSurfaceVariant,
                        ),
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
