import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/feed_query.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../widgets/common.dart';

/// Bottom sheet that filters the unified feed by publication and language.
///
/// Sources are listed alphabetically with their live health badge so it is
/// obvious why a publisher may have no headlines.
Future<void> showFeedFilterSheet(BuildContext context) async {
  final FeedController feed = context.read<FeedController>();
  final SourceRegistry registry = context.read<SourceRegistry>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => _FeedFilterSheet(
      initial: feed.query,
      registry: registry,
      onApply: feed.applyQuery,
    ),
  );
}

class _FeedFilterSheet extends StatefulWidget {
  const _FeedFilterSheet({
    required this.initial,
    required this.registry,
    required this.onApply,
  });

  final FeedQuery initial;
  final SourceRegistry registry;
  final Future<void> Function(FeedQuery) onApply;

  @override
  State<_FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends State<_FeedFilterSheet> {
  late Set<String> _sources = <String>{...widget.initial.sourceIds};
  late Set<SourceLanguage> _languages = <SourceLanguage>{...widget.initial.languages};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NewsSource> get _visibleSources {
    final List<NewsSource> all = widget.registry.withFeeds.toList()
      ..sort((NewsSource a, NewsSource b) => a
          .localizedName(bengali: context.isBengali)
          .compareTo(b.localizedName(bengali: context.isBengali)));
    if (_query.trim().isEmpty) return all;
    final Set<String> matched =
        widget.registry.search(_query).map((NewsSource s) => s.id).toSet();
    return all.where((NewsSource s) => matched.contains(s.id)).toList();
  }

  void _apply() {
    final FeedQuery next =
        widget.initial.copyWith(sourceIds: _sources, languages: _languages);
    Navigator.of(context).pop();
    widget.onApply(next);
  }

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final List<NewsSource> sources = _visibleSources;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    bengali ? 'ফিড ফিল্টার' : 'Filter the feed',
                    style: context.texts.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sources = <String>{};
                      _languages = <SourceLanguage>{};
                      _query = '';
                      _search.clear();
                    });
                  },
                  child: Text(context.strings.clear),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Text(
                  context.strings.filterLanguage,
                  style: context.texts.labelSmall?.copyWith(letterSpacing: 0.6),
                ),
                const SizedBox(width: 10),
                for (final SourceLanguage language in SourceLanguage.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        Labels.language(language, bengali: bengali),
                        style: context.texts.labelSmall?.copyWith(
                          color: _languages.contains(language)
                              ? context.colors.onPrimary
                              : context.colors.onSurface,
                        ),
                      ),
                      selected: _languages.contains(language),
                      visualDensity: VisualDensity.compact,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _languages.add(language);
                          } else {
                            _languages.remove(language);
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (String value) => setState(() => _query = value),
              style: context.texts.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                hintText: context.strings.searchInPapers,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: sources.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.strings.noResultsBody,
                      style: context.texts.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: sources.length,
                    itemBuilder: (BuildContext context, int index) {
                      final NewsSource source = sources[index];
                      final bool selected = _sources.contains(source.id);
                      return CheckboxListTile(
                        dense: true,
                        value: selected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _sources.add(source.id);
                            } else {
                              _sources.remove(source.id);
                            }
                          });
                        },
                        secondary: SourceAvatar(source: source, size: 32),
                        controlAffinity: ListTileControlAffinity.trailing,
                        title: Text(
                          source.localizedName(bengali: bengali),
                          style: context.texts.titleSmall?.copyWith(fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          Labels.language(source.language, bengali: bengali),
                          style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_sources.length} ${context.strings.sourceCountShort} · '
                      '${_languages.length} ${bengali ? 'ভাষা' : 'languages'}',
                      style: context.texts.labelSmall,
                    ),
                  ),
                  FilledButton(
                    onPressed: _apply,
                    child: Text(context.strings.done),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
