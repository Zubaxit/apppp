import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/feed_query.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// Bottom sheet that filters the unified feed by publication and language.
///
/// Sources are listed alphabetically with their live health badge so it is
/// obvious why a publisher may have no headlines. The sheet is a glass panel
/// over the feed: the list behind it stays faintly visible, so filtering feels
/// like narrowing what is already there rather than entering a new screen.
Future<void> showFeedFilterSheet(BuildContext context) async {
  final FeedController feed = context.read<FeedController>();
  final SourceRegistry registry = context.read<SourceRegistry>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
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
    final List<NewsSource> all = widget.registry.feedSources.toList()
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
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.84;

    return GlassPanel(
      radius: Tokens.radiusXl,
      blur: Tokens.blurStrong,
      elevation: 1.4,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Tokens.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.gutter, 2, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.strings.filterTitle,
                      style: context.texts.titleLarge?.copyWith(
                        fontFamily: Tokens.serif,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  JellySurface(
                    onTap: () {
                      Haptics.tick();
                      setState(() {
                        _sources = <String>{};
                        _languages = <SourceLanguage>{};
                        _query = '';
                        _search.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        context.strings.clear,
                        style: context.texts.labelSmall?.copyWith(
                          fontSize: 11,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
              child: Row(
                children: <Widget>[
                  for (final SourceLanguage language in SourceLanguage.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 7),
                      child: GlassChip(
                        label: Labels.language(language, bengali: bengali),
                        dense: true,
                        selected: _languages.contains(language),
                        onTap: () => setState(() {
                          if (!_languages.remove(language)) {
                            _languages.add(language);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
              child: GlassPanel(
                radius: Tokens.radiusPill,
                blur: 0,
                elevation: 0,
                sheen: false,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (String value) =>
                            setState(() => _query = value),
                        style: context.texts.bodyMedium?.copyWith(fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          hintText: context.strings.searchInPapers,
                          hintStyle:
                              context.texts.bodyMedium?.copyWith(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                      padding: const EdgeInsets.only(bottom: 8, top: 2),
                      itemCount: sources.length,
                      itemBuilder: (BuildContext context, int index) {
                        final NewsSource source = sources[index];
                        final bool selected = _sources.contains(source.id);
                        return JellySurface(
                          onTap: () {
                            Haptics.tick();
                            setState(() {
                              if (!_sources.remove(source.id)) {
                                _sources.add(source.id);
                              }
                            });
                          },
                          scale: 0.99,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Tokens.gutter,
                              vertical: 9,
                            ),
                            child: Row(
                              children: <Widget>[
                                SourceAvatar(source: source, size: 32),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        source.localizedName(bengali: bengali),
                                        style: context.texts.titleSmall?.copyWith(
                                          fontFamily: Tokens.serif,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        Labels.language(
                                          source.language,
                                          bengali: bengali,
                                        ),
                                        style: context.texts.labelSmall
                                            ?.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: Motion.of(context).tap,
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? context.colors.primary
                                            .withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: selected
                                          ? context.colors.primary
                                          : (context.isDark
                                              ? Tokens.nightHairline
                                              : Tokens.hairline),
                                      width: 1,
                                    ),
                                  ),
                                  child: selected
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: context.colors.primary,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_sources.length} ${context.strings.sourceCountShort} · '
                        '${_languages.length} ${bengali ? 'ভাষা' : 'languages'}',
                        style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                      ),
                    ),
                    JellyButton(
                      label: context.strings.done,
                      icon: Icons.check_rounded,
                      filled: true,
                      compact: true,
                      onPressed: _apply,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
