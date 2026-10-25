import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial_story.dart';

/// What the reader kept, and what she read.
///
/// Two registers live here on purpose: bookmarks are a library the reader
/// curates, history is a trace the app keeps for her. Both use the same row so
/// the difference is stated in words, not hidden in a different layout.
enum _SavedFilter { all, excerpt, link }

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _tab = 0;
  _SavedFilter _filter = _SavedFilter.all;

  void _select(int index) {
    if (_tab == index) return;
    Haptics.tick();
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final SavedController saved = context.watch<SavedController>();
    final SettingsController settings = context.watch<SettingsController>();
    final SourceRegistry registry = context.registry;
    final bool historyTab = _tab == 1;

    final List<SavedArticle> base = historyTab ? saved.history : saved.saved;
    final List<SavedArticle> items = base.where(_keeps).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _SavedHeader(
                count: historyTab ? saved.history.length : saved.count,
                historyTab: historyTab,
                onClearHistory: settings.historyEnabled && saved.history.isNotEmpty
                    ? () => _confirmClearHistory(context)
                    : null,
              ),
              _SavedTabs(
                index: _tab,
                savedCount: saved.count,
                onSelect: _select,
              ),
              if (!historyTab)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, 2),
                  child: Row(
                    children: <Widget>[
                      GlassChip(
                        label: context.strings.all,
                        dense: true,
                        selected: _filter == _SavedFilter.all,
                        onTap: () => setState(() => _filter = _SavedFilter.all),
                      ),
                      const SizedBox(width: 7),
                      GlassChip(
                        label: context.strings.savedExcerptBadge,
                        dense: true,
                        icon: Icons.notes_rounded,
                        selected: _filter == _SavedFilter.excerpt,
                        onTap: () => setState(() => _filter = _SavedFilter.excerpt),
                      ),
                      const SizedBox(width: 7),
                      GlassChip(
                        label: context.strings.savedLinkOnlyBadge,
                        dense: true,
                        icon: Icons.link_rounded,
                        selected: _filter == _SavedFilter.link,
                        onTap: () => setState(() => _filter = _SavedFilter.link),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.of(context).standard,
                  switchInCurve: Tokens.easeStandard,
                  child: _SavedList(
                    key: ValueKey<String>('$_tab-$_filter'),
                    loading: saved.isLoading,
                    items: items,
                    emptyIcon: historyTab
                        ? Icons.history_rounded
                        : Icons.bookmark_border_rounded,
                    emptyTitle: historyTab
                        ? context.strings.historyEmptyTitle
                        : context.strings.savedEmptyTitle,
                    emptyBody: historyTab
                        ? context.strings.historyEmptyBody
                        : context.strings.savedEmptyBody,
                    registry: registry,
                    note: historyTab ? null : context.strings.savedKindsNote,
                    onRemove: (String id) =>
                        context.read<SavedController>().remove(id),
                    showSavedAt: historyTab,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _keeps(SavedArticle item) {
    final bool hasExcerpt = (item.article.excerpt ?? '').trim().isNotEmpty;
    switch (_filter) {
      case _SavedFilter.all:
        return true;
      case _SavedFilter.excerpt:
        return hasExcerpt;
      case _SavedFilter.link:
        return !hasExcerpt;
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.strings.historyTitle),
        content: Text(context.strings.historyToggleBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.clear),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SavedController>().clearHistory();
    }
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader({
    required this.count,
    required this.historyTab,
    this.onClearHistory,
  });

  final int count;
  final bool historyTab;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter - 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.strings.savedTitle,
                  style: context.texts.headlineMedium?.copyWith(
                    fontFamily: Tokens.serif,
                    fontSize: 27,
                    height: 1.15,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${context.isBengali ? BengaliText.toBengaliDigits(count) : count} '
                  '${context.strings.articleCountShort}',
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0.2,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onClearHistory != null)
            GlassIconButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: context.strings.clear,
              onTap: onClearHistory,
            ),
        ],
      ),
    );
  }
}

/// A sliding capsule segmented control — the same control the home feed uses,
/// so switching registers feels like one gesture across the app.
class _SavedTabs extends StatelessWidget {
  const _SavedTabs({
    required this.index,
    required this.savedCount,
    required this.onSelect,
  });

  final int index;
  final int savedCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<Widget> labels = <Widget>[
      _tabLabel(context, 0, context.strings.savedTitle, '$savedCount'),
      _tabLabel(context, 1, context.strings.historyTitle, null),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 4, Tokens.gutter, 2),
      child: GlassPanel(
        radius: Tokens.radiusPill,
        blur: Tokens.blurSoft,
        elevation: 0.4,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double tabWidth = (constraints.maxWidth - 8) / 2;
            return SizedBox(
              height: 38,
              child: Stack(
                children: <Widget>[
                  AnimatedAlign(
                    duration: Motion.of(context).fast,
                    curve: Tokens.easeStandard,
                    alignment: index == 0
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    child: Container(
                      width: tabWidth,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Tokens.radiusPill),
                        color: context.colors.primary.withValues(alpha: 0.11),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.28),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Row(children: labels),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabLabel(BuildContext context, int i, String label, String? count) {
    final bool active = index == i;
    return Expanded(
      child: JellySurface(
        scale: 0.96,
        onTap: () => onSelect(i),
        child: SizedBox(
          height: 38,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  style: context.texts.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? context.colors.primary
                        : context.colors.onSurfaceVariant,
                  ),
                ),
                if (count != null && count != '0') ...<Widget>[
                  const SizedBox(width: 5),
                  Text(
                    count,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 9.5,
                      color: active
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedList extends StatelessWidget {
  const _SavedList({
    super.key,
    required this.loading,
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.registry,
    required this.onRemove,
    this.note,
    this.showSavedAt = false,
  });

  final bool loading;
  final List<SavedArticle> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final SourceRegistry registry;
  final ValueChanged<String> onRemove;
  final String? note;
  final bool showSavedAt;

  @override
  Widget build(BuildContext context) {
    if (loading) return const ArticleSkeleton(count: 4);
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: <Widget>[
          EmptyState(icon: emptyIcon, title: emptyTitle, body: emptyBody),
        ],
      );
    }
    final bool showNote = note != null && !showSavedAt;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 130),
      itemCount: items.length + (showNote ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (showNote && index == 0) {
          // Say what "saved" means before showing the list, so a saved link is
          // never mistaken for an offline copy of the story.
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.gutter,
              2,
              Tokens.gutter,
              12,
            ),
            child: Text(
              note!,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.6,
                height: 1.55,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          );
        }
        final SavedArticle item = items[index - (showNote ? 1 : 0)];
        final NewsSource? source = registry.byId(item.article.sourceId);
        final bool hasExcerpt = (item.article.excerpt ?? '').trim().isNotEmpty;
        return Dismissible(
          key: ValueKey<String>('saved-${item.article.id}'),
          direction: DismissDirection.endToStart,
          background: const _RemoveBackground(),
          onDismissed: (DismissDirection _) {
            Haptics.confirm();
            onRemove(item.article.id);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NewsCard(
                article: item.article,
                source: source,
                onTap: () => openArticle(context, item.article),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter + 12, 0, Tokens.gutter, 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      hasExcerpt ? Icons.notes_rounded : Icons.link_rounded,
                      size: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasExcerpt
                          ? context.strings.savedExcerptBadge
                          : context.strings.savedLinkOnlyBadge,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 9.8,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      showSavedAt
                          ? (BengaliText.relative(
                                item.savedAt,
                                bengali: context.isBengali,
                              ) ??
                              '')
                          : (BengaliText.relative(
                                item.article.publishedAt ?? item.savedAt,
                                bengali: context.isBengali,
                              ) ??
                              ''),
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 9.8,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        child: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: Tokens.danger.withValues(alpha: 0.16),
          child: const Icon(
            Icons.bookmark_remove_rounded,
            size: 20,
            color: Tokens.danger,
          ),
        ),
      ),
    );
  }
}
